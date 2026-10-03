#include "Library.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QSettings>
#include <QUrl>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QFile>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QSet>
#include <QDateTime>
#include <QSysInfo>
#include <QTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <algorithm>

#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/audioproperties.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>
#include <taglib/unsynchronizedlyricsframe.h>
#include <taglib/textidentificationframe.h>
#include <taglib/xiphcomment.h>

#ifdef Q_OS_UNIX
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>

class StderrSilencer {
public:
    StderrSilencer() {
        saved_ = dup(2);
        int nullFd = ::open("/dev/null", O_WRONLY);
        if (nullFd >= 0) {
            dup2(nullFd, 2);
            ::close(nullFd);
        }
    }
    ~StderrSilencer() {
        std::fflush(stderr);
        if (saved_ >= 0) {
            dup2(saved_, 2);
            ::close(saved_);
        }
    }
private:
    int saved_ = -1;
};
#else
class StderrSilencer {
public:
    StderrSilencer() {}
    ~StderrSilencer() {}
};
#endif

static TagLib::String toTaglib(const QString &s) {
    const QByteArray utf8 = s.toUtf8();
    return TagLib::String(utf8.constData(), TagLib::String::UTF8);
}

QString Library::lyricsDir() const {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                        + "/kute/txts";
    QDir().mkpath(dir);
    return dir;
}

QString Library::safeName(const QString &s) const {
    QString r = s;
    r.replace('/', '_');
    r.replace('\\', '_');
    r.replace(':', '_');
    return r;
}

QString Library::lyricsPath(const Track &t, bool lrc) const {
    return lyricsDir() + "/" + safeName(t.title) + (lrc ? ".lrc" : ".txt");
}

QString Library::offsetsPath() const {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + "/kute/offsets.json";
}

void Library::loadOffsets() {
    m_lrcOffsets.clear();
    QFile f(offsetsPath());
    if (!f.open(QIODevice::ReadOnly)) return;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return;

    const QJsonObject o = doc.object();
    for (auto it = o.begin(); it != o.end(); ++it) {
        m_lrcOffsets.insert(it.key(), it.value().toDouble(0.25));
    }
}

void Library::saveOffsets() {
    QJsonObject o;
    for (auto it = m_lrcOffsets.begin(); it != m_lrcOffsets.end(); ++it) {
        o.insert(it.key(), it.value());
    }
    const QString path = offsetsPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    }
}

double Library::getLrcOffset(int index) const {
    if (index < 0 || index >= m_tracks.count()) return 0.25;
    const Track *t = m_tracks.at(index);
    if (!t) return 0.25;
    return m_lrcOffsets.value(t->path, 0.25);
}

void Library::setLrcOffset(int index, double value) {
    if (index < 0 || index >= m_tracks.count()) return;
    const Track *t = m_tracks.at(index);
    if (!t) return;
    if (qFuzzyCompare(m_lrcOffsets.value(t->path, 0.25) + 1.0, value + 1.0)) return;
    m_lrcOffsets.insert(t->path, value);
    m_offsetRevision++;
    emit offsetRevisionChanged();
    if (m_offsetSaveTimer) m_offsetSaveTimer->start();
}

void Library::flushOffsetSave() {
    saveOffsets();
}

Library::Library(QObject *parent) : QObject(parent) {
    m_player = new QMediaPlayer(this);
    m_audioOutput = new QAudioOutput(this);
    m_player->setAudioOutput(m_audioOutput);

    m_rpc = new DiscordRPC(this);

    m_presenceTimer = new QTimer(this);
    m_presenceTimer->setSingleShot(true);
    m_presenceTimer->setInterval(30);
    connect(m_presenceTimer, &QTimer::timeout, this, &Library::flushPresence);

    m_offsetSaveTimer = new QTimer(this);
    m_offsetSaveTimer->setSingleShot(true);
    m_offsetSaveTimer->setInterval(600);
    connect(m_offsetSaveTimer, &QTimer::timeout, this, &Library::flushOffsetSave);

    m_osName = QSysInfo::prettyProductName();
    if (m_osName.isEmpty()) m_osName = QSysInfo::productType();

    if (m_osName.startsWith('"') && m_osName.endsWith('"') && m_osName.size() >= 2)
        m_osName = m_osName.mid(1, m_osName.size() - 2);
    if (m_osName.startsWith('\'') && m_osName.endsWith('\'') && m_osName.size() >= 2)
        m_osName = m_osName.mid(1, m_osName.size() - 2);
    m_osName = m_osName.trimmed();

    QSettings s;
    const int savedVol = s.value("player/volume", 70).toInt();
    m_audioOutput->setVolume(savedVol / 100.0);

    m_sortField = s.value("library/sortField", "path").toString();
    m_sortAscending = s.value("library/sortAscending", true).toBool();
    m_infoPanelVisible = s.value("ui/infoPanelVisible", true).toBool();
    m_repeatMode = s.value("player/repeatMode", 0).toInt();

    loadOffsets();

    connect(m_player, &QMediaPlayer::positionChanged,
            this, [this](qint64) { emit positionChanged(); });

    connect(m_player, &QMediaPlayer::durationChanged,
            this, [this](qint64) { emit durationChanged(); });

    connect(m_player, &QMediaPlayer::playbackStateChanged,
            this, [this](QMediaPlayer::PlaybackState) {
        emit isPlayingChanged();
        schedulePresence();
    });

    connect(m_player, &QMediaPlayer::mediaStatusChanged,
            this, [this](QMediaPlayer::MediaStatus st) {
        if (st != QMediaPlayer::EndOfMedia) return;
        if (m_repeatMode == 2) {
            m_player->setPosition(0);
            m_player->play();
            schedulePresence();
        } else if (m_repeatMode == 1) {
            next();
        } else {
            m_intentPlaying = false;
            schedulePresence();
        }
    });

    connect(m_rpc, &DiscordRPC::connectedChanged,
            this, [this]() {
        emit discordConnectedChanged();
        if (m_rpc->connected() && isPlaying())
            schedulePresence();
    });

    connect(m_rpc, &DiscordRPC::enabledChanged,
            this, [this]() {
        emit discordRpcEnabledChanged();
        schedulePresence();
    });

    const QString last = s.value("library/folder").toString();
    if (!last.isEmpty() && QDir(last).exists()) loadFolder(last);
}

bool Library::discordRpcEnabled() const { return m_rpc->enabled(); }
void Library::setDiscordRpcEnabled(bool v) { m_rpc->setEnabled(v); }
bool Library::discordConnected() const { return m_rpc->connected(); }

void Library::schedulePresence() {
    if (!m_presenceTimer) return;

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qint64 sinceLast = now - m_lastPresenceSent;

    int interval = 200;
    if (sinceLast < 1000)       interval = 700;
    else if (sinceLast < 3000)  interval = 400;

    m_lastPresenceSent = now;
    m_presenceTimer->setInterval(interval);
    m_presenceTimer->start();
}

void Library::flushPresence() {
    if (!m_rpc) return;
    if (!m_rpc->enabled()) return;

    if (!m_intentPlaying || m_currentTrack.path.isEmpty()) {
        m_rpc->clearActivity();
        return;
    }

    const qint64 pos = m_player->position();
    const qint64 startSec = QDateTime::currentSecsSinceEpoch() - (pos / 1000);

    QString stateLine = m_currentTrack.artist;
    if (stateLine.isEmpty() || stateLine == "Unknown Artist")
        stateLine.clear();

    if (!m_osName.isEmpty()) {
        if (!stateLine.isEmpty())
            stateLine += " • On " + m_osName;
        else
            stateLine = "On " + m_osName;
    }

    m_rpc->setActivity(m_currentTrack.title, stateLine, startSec);
}

QString Library::folderName() const {
    if (m_folder.isEmpty()) return {};
    return QDir(m_folder).dirName();
}

bool Library::isPlaying() const {
    return m_player->playbackState() == QMediaPlayer::PlayingState;
}

qint64 Library::position() const { return m_player->position(); }
qint64 Library::duration() const { return m_player->duration(); }
int Library::volume() const { return qRound(m_audioOutput->volume() * 100.0); }

void Library::setVolume(int v) {
    v = qBound(0, v, 100);
    m_audioOutput->setVolume(v / 100.0);
    QSettings().setValue("player/volume", v);
    emit volumeChanged();
}

void Library::setInfoPanelVisible(bool v) {
    if (m_infoPanelVisible == v) return;
    m_infoPanelVisible = v;
    QSettings().setValue("ui/infoPanelVisible", v);
    emit infoPanelVisibleChanged();
}

QString Library::formatDuration(qint64 ms) const {
    if (ms <= 0) return "--:--";
    const qint64 total = ms / 1000;
    const qint64 m = total / 60;
    const qint64 s = total % 60;
    return QString("%1:%2").arg(m).arg(s, 2, 10, QChar('0'));
}

QString Library::formatFileSize(qint64 bytes) const {
    if (bytes <= 0) return "--";
    const double kb = bytes / 1024.0;
    const double mb = kb / 1024.0;
    if (mb >= 1.0) return QString::number(mb, 'f', 1) + " MB";
    return QString::number(kb, 'f', 0) + " KB";
}

QString Library::formatSampleRate(int hz) const {
    if (hz <= 0) return "--";
    return QString::number(hz / 1000.0, 'f', 1) + " kHz";
}

QString Library::coverCacheDir() const {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                        + "/covers";
    QDir().mkpath(dir);
    return dir;
}

QString Library::thumbCacheDir() const {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                        + "/thumbs";
    QDir().mkpath(dir);
    return dir;
}

void Library::extractImages(const QString &filePath,
                            QString &coverOut,
                            QString &thumbOut) const {
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5).toHex());

    const QString coverPath = coverCacheDir() + "/" + hash + ".jpg";
    const QString thumbPath = thumbCacheDir() + "/" + hash + ".png";

    if (QFile::exists(coverPath) && QFile::exists(thumbPath)) {
        coverOut = coverPath;
        thumbOut = thumbPath;
        return;
    }

    QByteArray data;
    {
        StderrSilencer silencer;
        TagLib::FileRef f(filePath.toUtf8().constData());
        if (f.isNull() || !f.file()) return;

        TagLib::File *file = f.file();

        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
            if (auto *tag = mpeg->ID3v2Tag()) {
                const auto list = tag->frameList("APIC");
                if (!list.isEmpty()) {
                    if (auto *pic = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(list.front())) {
                        data = QByteArray(pic->picture().data(), pic->picture().size());
                    }
                }
            }
        } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
            const auto pics = flac->pictureList();
            if (!pics.isEmpty()) {
                const auto *pic = pics.front();
                data = QByteArray(pic->data().data(), pic->data().size());
            }
        }
    }

    if (data.isEmpty()) return;

    QImage src;
    if (!src.loadFromData(data)) return;

    if (!QFile::exists(coverPath)) {
        QImage cover = (src.width() > 500 || src.height() > 500)
            ? src.scaled(500, 500, Qt::KeepAspectRatio, Qt::SmoothTransformation)
            : src;
        if (cover.save(coverPath, "JPEG", 88)) coverOut = coverPath;
    } else {
        coverOut = coverPath;
    }

    if (!QFile::exists(thumbPath)) {
        const int sz = 80;
        QImage t = src.scaled(sz, sz, Qt::KeepAspectRatioByExpanding,
                              Qt::SmoothTransformation);
        const int x = (t.width() - sz) / 2;
        const int y = (t.height() - sz) / 2;
        t = t.copy(x, y, sz, sz);

        QImage rounded(sz, sz, QImage::Format_ARGB32);
        rounded.fill(Qt::transparent);

        QPainter p(&rounded);
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setRenderHint(QPainter::SmoothPixmapTransform, true);
        QPainterPath path;
        path.addRoundedRect(0, 0, sz, sz, 16, 16);
        p.setClipPath(path);
        p.drawImage(0, 0, t);
        p.end();

        if (rounded.save(thumbPath, "PNG")) thumbOut = thumbPath;
    } else {
        thumbOut = thumbPath;
    }
}

void Library::loadFolder(const QString &path) {
    QString localPath = path;
    if (localPath.startsWith("file://")) localPath = QUrl(localPath).toLocalFile();
    if (localPath.isEmpty() || !QDir(localPath).exists()) return;

    const QStringList filters = {
        "*.mp3", "*.flac", "*.ogg", "*.opus",
        "*.wav", "*.m4a", "*.aac"
    };

    m_allTracks.clear();
    QDirIterator it(localPath, filters, QDir::Files, QDirIterator::Subdirectories);

    while (it.hasNext()) {
        const QString filePath = it.next();
        Track t;
        t.path = filePath;

        const QFileInfo info(filePath);
        t.fileSize = info.size();
        t.format = info.suffix().toUpper();

        {
            StderrSilencer silencer;
            TagLib::FileRef f(filePath.toUtf8().constData());
            if (!f.isNull() && f.tag()) {
                TagLib::Tag *tag = f.tag();

                const QString tagTitle  = QString::fromUtf8(tag->title().to8Bit(true).c_str());
                const QString tagArtist = QString::fromUtf8(tag->artist().to8Bit(true).c_str());
                const QString tagAlbum  = QString::fromUtf8(tag->album().to8Bit(true).c_str());

                t.title  = tagTitle.isEmpty()  ? info.completeBaseName() : tagTitle.trimmed();
                t.artist = tagArtist.isEmpty() ? "Unknown Artist" : tagArtist.trimmed();
                t.album  = tagAlbum.isEmpty()  ? "Unknown Album"  : tagAlbum.trimmed();
                t.year   = tag->year();

                if (f.audioProperties()) {
                    t.durationMs = f.audioProperties()->lengthInMilliseconds();
                    t.bitrate    = f.audioProperties()->bitrate();
                    t.sampleRate = f.audioProperties()->sampleRate();
                    t.channels   = f.audioProperties()->channels();
                }
            } else {
                t.title  = info.completeBaseName();
                t.artist = "Unknown Artist";
                t.album  = "Unknown Album";
            }
        }

        extractImages(filePath, t.cover, t.thumb);
        m_allTracks.append(t);
    }

    m_player->stop();
    m_player->setSource(QUrl());
    m_folder = localPath;
    m_currentIndex = -1;
    m_currentTrack = Track();
    m_intentPlaying = false;
    m_filterArtist.clear();
    m_filterText.clear();
    m_searchQuery.clear();
    m_reorderMode = false;
    m_customOrder.clear();
    if (m_sortField == "custom") loadPlaylistOrder();
    rebuildArtists();
    sortAndApply();
    m_searchResults.clear();

    QSettings s;
    s.setValue("library/folder", localPath);

    emit folderChanged();
    emit trackCountChanged();
    emit currentChanged();
    emit filterArtistChanged();
    emit filterTextChanged();
    emit searchQueryChanged();
    emit reorderModeChanged();
    schedulePresence();
}

QString Library::playlistOrderPath() const {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + "/kute/playlist_order.json";
}

void Library::loadPlaylistOrder() {
    m_customOrder.clear();

    QStringList candidates;
    candidates << playlistOrderPath();
    candidates << (QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                   + "/kute-player/playlist_order.json");

    for (const QString &path : candidates) {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) continue;

        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) continue;

        const QJsonObject o = doc.object();

        QJsonArray arr = o.value("order").toArray();
        if (arr.isEmpty()) arr = o.value("playlistOrder").toArray();
        if (arr.isEmpty()) continue;

        for (const auto &v : arr) {
            const QString p = v.toString();
            if (!p.isEmpty()) m_customOrder.append(p);
        }
        if (!m_customOrder.isEmpty()) return;
    }
}

void Library::savePlaylistOrder() {
    QStringList order;
    if (m_tracks.count() > 0) {
        for (int i = 0; i < m_tracks.count(); ++i) {
            const Track *t = m_tracks.at(i);
            if (t) order.append(t->path);
        }
    } else if (!m_customOrder.isEmpty()) {
        order = m_customOrder;
    } else {
        return;
    }
    m_customOrder = order;

    QJsonArray arr;
    for (const QString &p : order) arr.append(p);

    QJsonObject o;
    o["order"] = arr;
    o["libraryPath"] = m_folder;
    o["lastModified"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    const QString path = playlistOrderPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    }
}

void Library::sortAndApply() {
    const QString currentPath = m_currentTrack.path;
    const QString q = m_filterText.toLower().trimmed();

    QList<Track> filtered;
    filtered.reserve(m_allTracks.size());

    for (const Track &t : m_allTracks) {
        if (!m_filterArtist.isEmpty() && t.artist != m_filterArtist) continue;
        if (!q.isEmpty()) {
            if (!t.title.toLower().contains(q) &&
                !t.artist.toLower().contains(q) &&
                !t.album.toLower().contains(q))
                continue;
        }
        filtered.append(t);
    }

    if (m_sortField == "custom" && !m_customOrder.isEmpty()) {
        QHash<QString, int> rank;
        rank.reserve(m_customOrder.size());
        for (int i = 0; i < m_customOrder.size(); ++i)
            rank.insert(m_customOrder[i], i);

        std::stable_sort(filtered.begin(), filtered.end(),
            [&rank](const Track &a, const Track &b) {
                const int ra = rank.value(a.path, 999999);
                const int rb = rank.value(b.path, 999999);
                return ra < rb;
            });
    } else {
        std::stable_sort(filtered.begin(), filtered.end(),
            [this](const Track &a, const Track &b) {
                int cmp = 0;
                if (m_sortField == "title") {
                    cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
                    if (cmp == 0) cmp = QString::compare(a.artist, b.artist, Qt::CaseInsensitive);
                } else if (m_sortField == "artist") {
                    cmp = QString::compare(a.artist, b.artist, Qt::CaseInsensitive);
                    if (cmp == 0) cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
                } else if (m_sortField == "album") {
                    cmp = QString::compare(a.album, b.album, Qt::CaseInsensitive);
                    if (cmp == 0) cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
                } else if (m_sortField == "duration") {
                    cmp = (a.durationMs < b.durationMs) ? -1
                        : (a.durationMs > b.durationMs) ? 1 : 0;
                } else {
                    cmp = QString::compare(a.path, b.path, Qt::CaseInsensitive);
                }
                return m_sortAscending ? (cmp < 0) : (cmp > 0);
            });
    }

    m_tracks.setTracksAnimated(filtered);

    m_currentIndex = -1;
    if (!currentPath.isEmpty()) {
        for (int i = 0; i < filtered.size(); ++i) {
            if (filtered[i].path == currentPath) { m_currentIndex = i; break; }
        }
    }
}

void Library::rebuildArtists() {
    QSet<QString> set;
    const QString q = m_filterText.toLower().trimmed();
    for (const Track &t : m_allTracks) {
        if (t.artist.isEmpty() || t.artist == "Unknown Artist") continue;
        if (!q.isEmpty() && !t.artist.toLower().contains(q)) continue;
        set.insert(t.artist);
    }
    QStringList list = set.values();
    list.sort(Qt::CaseInsensitive);
    m_artists = list;
    emit artistsChanged();
}

void Library::rebuildSearch() {
    if (m_searchQuery.trimmed().isEmpty()) {
        m_searchResults.clear();
        return;
    }

    const QString q = m_searchQuery.toLower();
    QList<Track> results;
    results.reserve(m_allTracks.size());

    for (const Track &t : m_allTracks) {
        if (t.title.toLower().contains(q) ||
            t.artist.toLower().contains(q) ||
            t.album.toLower().contains(q)) {
            results.append(t);
        }
    }

    std::stable_sort(results.begin(), results.end(),
        [this](const Track &a, const Track &b) {
            int cmp = 0;
            if (m_sortField == "title") {
                cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
                if (cmp == 0) cmp = QString::compare(a.artist, b.artist, Qt::CaseInsensitive);
            } else if (m_sortField == "artist") {
                cmp = QString::compare(a.artist, b.artist, Qt::CaseInsensitive);
                if (cmp == 0) cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
            } else if (m_sortField == "album") {
                cmp = QString::compare(a.album, b.album, Qt::CaseInsensitive);
                if (cmp == 0) cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
            } else if (m_sortField == "duration") {
                cmp = (a.durationMs < b.durationMs) ? -1
                    : (a.durationMs > b.durationMs) ? 1 : 0;
            } else {
                cmp = QString::compare(a.path, b.path, Qt::CaseInsensitive);
            }
            return m_sortAscending ? (cmp < 0) : (cmp > 0);
        });

    m_searchResults.updateFiltered(results);
}

void Library::applySort(const QString &field, bool ascending) {
    if (m_sortField == field && m_sortAscending == ascending) return;

    if (field != "custom" && m_reorderMode) {
        m_reorderMode = false;
        emit reorderModeChanged();
    }

    m_sortField = field;
    m_sortAscending = ascending;

    if (field == "custom") {
        loadPlaylistOrder();
        if (m_customOrder.isEmpty()) {
            for (const Track &t : m_allTracks) m_customOrder.append(t.path);
            savePlaylistOrder();
        }
    }

    QSettings s;
    s.setValue("library/sortField", field);
    s.setValue("library/sortAscending", ascending);

    sortAndApply();
    rebuildSearch();
    emit sortChanged();
    emit currentChanged();
}

void Library::setFilterArtist(const QString &artist) {
    if (m_filterArtist == artist) return;
    m_filterArtist = artist;
    sortAndApply();
    emit filterArtistChanged();
    emit currentChanged();
}

void Library::setFilterText(const QString &text) {
    if (m_filterText == text) return;
    m_filterText = text;
    rebuildArtists();
    sortAndApply();
    emit filterTextChanged();
    emit currentChanged();
}

void Library::clearFilter() {
    bool changed = false;
    if (!m_filterArtist.isEmpty()) {
        m_filterArtist.clear();
        emit filterArtistChanged();
        changed = true;
    }
    if (!m_filterText.isEmpty()) {
        m_filterText.clear();
        emit filterTextChanged();
        changed = true;
    }
    if (changed) {
        rebuildArtists();
        sortAndApply();
        emit currentChanged();
    }
}

void Library::setSearch(const QString &q) {
    if (m_searchQuery == q) return;
    m_searchQuery = q;
    rebuildSearch();
    emit searchQueryChanged();
}

void Library::toggleReorderMode() {
    if (m_sortField != "custom") {
        applySort("custom", true);
    }
    m_reorderMode = !m_reorderMode;
    emit reorderModeChanged();

    if (!m_reorderMode) {
        savePlaylistOrder();
    }
}

void Library::moveTrack(int from, int to) {
    if (m_sortField != "custom") return;
    if (from == to) return;
    if (from < 0 || to < 0) return;
    if (from >= m_tracks.count() || to >= m_tracks.count()) return;

    m_tracks.moveRow(from, to);

    if (m_currentIndex == from) {
        m_currentIndex = to;
    } else if (from < m_currentIndex && to >= m_currentIndex) {
        m_currentIndex--;
    } else if (from > m_currentIndex && to <= m_currentIndex) {
        m_currentIndex++;
    }
    emit currentChanged();

    savePlaylistOrder();
}

void Library::cycleRepeat() {
    m_repeatMode = (m_repeatMode + 1) % 3;
    QSettings().setValue("player/repeatMode", m_repeatMode);
    emit repeatModeChanged();
}

void Library::startTrack(const Track &t) {
    m_currentTrack = t;
    m_intentPlaying = true;
    m_player->stop();
    m_player->setSource(QUrl());
    m_player->setSource(QUrl::fromLocalFile(t.path));
    m_player->play();
    emit currentChanged();
    schedulePresence();
}

void Library::playIndex(int index) {
    if (index < 0 || index >= m_tracks.count()) return;
    const Track *t = m_tracks.at(index);
    if (!t) return;
    m_currentIndex = index;
    startTrack(*t);
}

void Library::playSearchIndex(int index) {
    if (index < 0 || index >= m_searchResults.count()) return;
    const Track *t = m_searchResults.at(index);
    if (!t) return;

    m_currentIndex = -1;
    for (int i = 0; i < m_tracks.count(); ++i) {
        const Track *main = m_tracks.at(i);
        if (main && main->path == t->path) { m_currentIndex = i; break; }
    }
    startTrack(*t);
}

void Library::setCurrent(int index) { playIndex(index); }

void Library::togglePlayPause() {
    const auto state = m_player->playbackState();
    if (state == QMediaPlayer::PlayingState) {
        m_intentPlaying = false;
        m_player->pause();
    } else if (state == QMediaPlayer::PausedState) {
        m_intentPlaying = true;
        m_player->play();
    } else if (!m_currentTrack.path.isEmpty()) {
        m_intentPlaying = true;
        m_player->play();
    } else if (m_tracks.count() > 0) {
        playIndex(m_currentIndex >= 0 ? m_currentIndex : 0);
    }
}

void Library::next() {
    if (m_tracks.count() == 0) return;
    if (m_currentIndex < 0) { playIndex(0); return; }
    playIndex((m_currentIndex + 1) % m_tracks.count());
}

void Library::prev() {
    if (m_tracks.count() == 0) return;
    if (m_currentIndex < 0) { playIndex(0); return; }
    playIndex((m_currentIndex - 1 + m_tracks.count()) % m_tracks.count());
}

void Library::seek(qint64 pos) {
    m_player->setPosition(pos);
    schedulePresence();
}

bool Library::saveMetadata(int index,
                           const QString &title,
                           const QString &artist,
                           const QString &album,
                           const QString &coverSourcePath) {
    if (index < 0 || index >= m_tracks.count()) return false;
    const Track *old = m_tracks.at(index);
    if (!old) return false;

    const QString path = old->path;
    const bool wasCurrent = (index == m_currentIndex);
    const bool wasPlaying = isPlaying();
    const qint64 savedPos = wasCurrent ? m_player->position() : 0;

    const QString finalAlbum = album.isEmpty() ? QStringLiteral("Unknown Album") : album;

    if (wasCurrent) {
        m_player->stop();
        m_player->setSource(QUrl());
        m_intentPlaying = false;
    }

    const bool wantCover = !coverSourcePath.isEmpty();

    bool ok = false;
    {
        StderrSilencer silencer;

        TagLib::FileRef fr(path.toUtf8().constData());
        if (fr.isNull() || !fr.file()) {
            if (wasCurrent) {
                m_player->setSource(QUrl::fromLocalFile(path));
                m_player->setPosition(savedPos);
                if (wasPlaying) {
                    m_player->play();
                    m_intentPlaying = true;
                }
            }
            return false;
        }

        TagLib::File *file = fr.file();

        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
            TagLib::ID3v2::Tag *tag = mpeg->ID3v2Tag(true);
            if (!title.isEmpty()) tag->setTitle(toTaglib(title));
            if (!artist.isEmpty()) tag->setArtist(toTaglib(artist));
            tag->setAlbum(toTaglib(finalAlbum));

            if (wantCover) {
                QFile img(coverSourcePath);
                if (img.open(QIODevice::ReadOnly)) {
                    const QByteArray data = img.readAll();
                    QString mime = "image/jpeg";
                    if (coverSourcePath.endsWith(".png", Qt::CaseInsensitive)) mime = "image/png";
                    else if (coverSourcePath.endsWith(".webp", Qt::CaseInsensitive)) mime = "image/webp";

                    tag->removeFrames("APIC");
                    auto *frame = new TagLib::ID3v2::AttachedPictureFrame;
                    frame->setMimeType(mime.toStdString());
                    frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
                    frame->setPicture(TagLib::ByteVector(data.constData(), data.size()));
                    tag->addFrame(frame);
                }
            }

            ok = mpeg->save();
        } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
            if (flac->tag()) {
                if (!title.isEmpty()) flac->tag()->setTitle(toTaglib(title));
                if (!artist.isEmpty()) flac->tag()->setArtist(toTaglib(artist));
                flac->tag()->setAlbum(toTaglib(finalAlbum));
            }

            if (wantCover) {
                QFile img(coverSourcePath);
                if (img.open(QIODevice::ReadOnly)) {
                    const QByteArray data = img.readAll();
                    QString mime = "image/jpeg";
                    if (coverSourcePath.endsWith(".png", Qt::CaseInsensitive)) mime = "image/png";

                    flac->removePictures();
                    auto *pic = new TagLib::FLAC::Picture;
                    pic->setMimeType(mime.toStdString());
                    pic->setType(TagLib::FLAC::Picture::FrontCover);
                    pic->setData(TagLib::ByteVector(data.constData(), data.size()));
                    flac->addPicture(pic);
                }
            }

            ok = flac->save();
        } else {
            TagLib::Tag *tag = file->tag();
            if (!tag) {
                if (wasCurrent) {
                    m_player->setSource(QUrl::fromLocalFile(path));
                    m_player->setPosition(savedPos);
                    if (wasPlaying) {
                        m_player->play();
                        m_intentPlaying = true;
                    }
                }
                return false;
            }
            if (!title.isEmpty()) tag->setTitle(toTaglib(title));
            if (!artist.isEmpty()) tag->setArtist(toTaglib(artist));
            tag->setAlbum(toTaglib(finalAlbum));
            ok = file->save();
        }
    }

    if (!ok) {
        if (wasCurrent) {
            m_player->setSource(QUrl::fromLocalFile(path));
            m_player->setPosition(savedPos);
            if (wasPlaying) {
                m_player->play();
                m_intentPlaying = true;
            }
        }
        return false;
    }

    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(path.toUtf8(), QCryptographicHash::Md5).toHex());
    QFile::remove(coverCacheDir() + "/" + hash + ".jpg");
    QFile::remove(thumbCacheDir() + "/" + hash + ".png");

    Track updated = *old;
    if (!title.isEmpty()) updated.title = title;
    if (!artist.isEmpty()) updated.artist = artist;
    updated.album = finalAlbum;

    QString newCover, newThumb;
    extractImages(path, newCover, newThumb);
    if (!newCover.isEmpty()) updated.cover = newCover;
    if (!newThumb.isEmpty()) updated.thumb = newThumb;

    for (auto &t : m_allTracks) {
        if (t.path == path) { t = updated; break; }
    }

    m_tracks.updateTrack(index, updated);
    if (wasCurrent) m_currentTrack = updated;

    if (wasCurrent) {
        m_player->setSource(QUrl::fromLocalFile(path));
        m_player->setPosition(savedPos);
        if (wasPlaying) {
            m_player->play();
            m_intentPlaying = true;
            schedulePresence();
        }
    }

    rebuildArtists();
    emit currentChanged();

    m_coverVersion++;
    emit coverVersionChanged();
    return true;
}

bool Library::saveCoverTo(const QString &destPath) {
    if (m_currentTrack.path.isEmpty()) return false;

    QString local = destPath;
    if (local.startsWith("file://")) local = QUrl(local).toLocalFile();
    if (local.isEmpty()) return false;

    QByteArray data;
    {
        StderrSilencer silencer;
        TagLib::FileRef f(m_currentTrack.path.toUtf8().constData());
        if (f.isNull() || !f.file()) return false;
        TagLib::File *file = f.file();

        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
            if (auto *tag = mpeg->ID3v2Tag()) {
                const auto list = tag->frameList("APIC");
                if (!list.isEmpty()) {
                    if (auto *pic = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(list.front()))
                        data = QByteArray(pic->picture().data(), pic->picture().size());
                }
            }
        } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
            const auto pics = flac->pictureList();
            if (!pics.isEmpty()) {
                const auto *pic = pics.front();
                data = QByteArray(pic->data().data(), pic->data().size());
            }
        }
    }

    if (data.isEmpty()) return false;
    if (QFile::exists(local)) QFile::remove(local);

    QFile out(local);
    if (!out.open(QIODevice::WriteOnly)) return false;
    out.write(data);
    return true;
}

QString Library::readTextFromTags(const QString &path) const {
    StderrSilencer silencer;
    TagLib::FileRef fr(path.toUtf8().constData());
    if (fr.isNull() || !fr.file()) return QString();

    TagLib::File *file = fr.file();

    if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
        if (auto *tag = mpeg->ID3v2Tag()) {
            const auto usltList = tag->frameList("USLT");
            if (!usltList.isEmpty()) {
                if (auto *frame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame*>(usltList.front())) {
                    const QString s = QString::fromUtf8(frame->text().to8Bit(true).c_str());
                    if (!s.trimmed().isEmpty()) return s;
                }
            }

            const auto txxxList = tag->frameList("TXXX");
            for (const auto &f : txxxList) {
                if (auto *frame = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame*>(f)) {
                    const QString desc = QString::fromUtf8(frame->description().to8Bit(true).c_str()).toLower();
                    if (desc.contains("lyric") || desc.contains("text")) {
                        const auto fields = frame->fieldList();
                        for (const auto &field : fields) {
                            const QString s = QString::fromUtf8(field.to8Bit(true).c_str());
                            if (s.trimmed().isEmpty()) continue;
                            if (s.toLower() == desc) continue;
                            if (s.contains('\n') || s.length() > 60) return s;
                        }
                    }
                }
            }
        }
    } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
        if (auto *xc = flac->xiphComment()) {
            const auto map = xc->fieldListMap();
            for (auto it = map.begin(); it != map.end(); ++it) {
                const QString key = QString::fromUtf8(it->first.to8Bit(true).c_str()).toLower();
                if (key.contains("lyric") || key == "text") {
                    if (!it->second.isEmpty()) {
                        const QString s = QString::fromUtf8(it->second.front().to8Bit(true).c_str());
                        if (!s.trimmed().isEmpty()) return s;
                    }
                }
            }
        }
    }

    return QString();
}

bool Library::writeTextToTags(const QString &path, const QString &content) {
    StderrSilencer silencer;
    TagLib::FileRef fr(path.toUtf8().constData());
    if (fr.isNull() || !fr.file()) return false;

    TagLib::File *file = fr.file();

    if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
        TagLib::ID3v2::Tag *tag = mpeg->ID3v2Tag(true);

        tag->removeFrames("USLT");
        tag->removeFrames("TXXX");

        if (!content.trimmed().isEmpty()) {
            auto *frame = new TagLib::ID3v2::UnsynchronizedLyricsFrame;
            frame->setLanguage("eng");
            frame->setDescription("");
            frame->setText(toTaglib(content));
            tag->addFrame(frame);
        }

        return mpeg->save();
    } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
        if (!flac->xiphComment()) return false;

        auto *xc = flac->xiphComment();
        xc->removeFields("LYRICS");
        xc->removeFields("UNSYNCEDLYRICS");
        xc->removeFields("TEXT");

        if (!content.trimmed().isEmpty()) {
            xc->addField("LYRICS", toTaglib(content), true);
        }

        return flac->save();
    } else {
        TagLib::Tag *tag = file->tag();
        if (!tag) return false;
        if (content.trimmed().isEmpty()) {
            tag->setComment("");
        } else {
            tag->setComment(toTaglib(content));
        }
        return file->save();
    }
}

QString Library::loadTrackText(int index, bool preferLrc) {
    if (index < 0 || index >= m_tracks.count()) return QString();
    const Track *t = m_tracks.at(index);
    if (!t) return QString();

    if (preferLrc) {
        const QString lrc = lyricsPath(*t, true);
        if (QFile::exists(lrc)) {
            QFile f(lrc);
            if (f.open(QIODevice::ReadOnly)) {
                const QString s = QString::fromUtf8(f.readAll());
                if (!s.trimmed().isEmpty()) return s;
            }
        }
        return QString();
    } else {
        return readTextFromTags(t->path);
    }
}

bool Library::saveTrackText(int index, const QString &content, bool isLrc) {
    if (index < 0 || index >= m_tracks.count()) return false;
    const Track *t = m_tracks.at(index);
    if (!t) return false;

    if (isLrc) {
        const QString path = lyricsPath(*t, true);
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
        f.write(content.toUtf8());
        f.close();
        return true;
    } else {
        return writeTextToTags(t->path, content);
    }
}