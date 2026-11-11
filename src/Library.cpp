#include "Library.h"
#include "LibraryInternal.h"

#include <QMap>
#include <QVariantMap>

#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QUrl>
#include <QStandardPaths>
#include <QDateTime>
#include <QSysInfo>
#include <QTimer>
#include <QCryptographicHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

Library::Library(QObject *parent) : QObject(parent) {
    m_settings = new QSettings(this);

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

    m_likedSaveTimer = new QTimer(this);
    m_likedSaveTimer->setSingleShot(true);
    m_likedSaveTimer->setInterval(600);
    connect(m_likedSaveTimer, &QTimer::timeout, this, &Library::flushLikedSave);

    m_osName = QSysInfo::prettyProductName();
    if (m_osName.isEmpty()) m_osName = QSysInfo::productType();
    if (m_osName.startsWith('"') && m_osName.endsWith('"') && m_osName.size() >= 2)
        m_osName = m_osName.mid(1, m_osName.size() - 2);
    if (m_osName.startsWith('\'') && m_osName.endsWith('\'') && m_osName.size() >= 2)
        m_osName = m_osName.mid(1, m_osName.size() - 2);
    m_osName = m_osName.trimmed();

    const int savedVol = m_settings->value("player/volume", 70).toInt();
    m_audioOutput->setVolume(savedVol / 100.0);

    m_sortField = m_settings->value("library/sortField", "path").toString();
    m_sortAscending = m_settings->value("library/sortAscending", true).toBool();
    m_infoPanelVisible = m_settings->value("ui/infoPanelVisible", true).toBool();
    m_repeatMode = m_settings->value("player/repeatMode", 0).toInt();
    m_artistsAscending = m_settings->value("library/artistsAscending", true).toBool();
    m_albumsAscending  = m_settings->value("library/albumsAscending", true).toBool();

    loadMetaCache();
    loadOffsets();

    m_visualizerEnabled = m_settings->value("ui/visualizerEnabled", true).toBool();
    m_visualizer = new AudioVisualizer(m_player, this);
    m_visualizer->setEnabled(m_visualizerEnabled);

    m_metaSaveTimer = new QTimer(this);
    m_metaSaveTimer->setSingleShot(true);
    m_metaSaveTimer->setInterval(1000);
    connect(m_metaSaveTimer, &QTimer::timeout, this, &Library::saveMetaCache);

    m_folderWatcher = new QFileSystemWatcher(this);
    m_rescanTimer = new QTimer(this);
    m_rescanTimer->setSingleShot(true);
    m_rescanTimer->setInterval(500);
    connect(m_folderWatcher, &QFileSystemWatcher::directoryChanged,
            this, [this](const QString &) { if (m_rescanTimer) m_rescanTimer->start(); });
    connect(m_rescanTimer, &QTimer::timeout, this, &Library::refreshLibrary);

    migratePlaylistCovers();

    m_playlistModel.setCoverResolver([this](const QString &id) {
        return playlistCover(id);
    });

    m_playlistsProxy = new PlaylistFilterModel(this);
    m_playlistsProxy->setSourceModel(&m_playlistModel);
    m_playlistsProxy->setFilterRole(PlaylistModel::NameRole);

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

#ifdef Q_OS_WIN
        if (st == QMediaPlayer::LoadedMedia && m_pendingPlay) {
            m_pendingPlay = false;
            if (m_intentPlaying && m_player->playbackState() != QMediaPlayer::PlayingState) {
                m_player->play();
            }
            return;
        }

        if (st == QMediaPlayer::EndOfMedia && m_intentPlaying && m_expectedDuration > 5000) {
            const qint64 pos = m_player->position();
            if (pos < 3000 && m_playRetries < 3) {
                m_playRetries++;
                m_player->setPosition(0);
                m_player->play();
                return;
            }
            m_playRetries = 0;
        }
#endif

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

    const QString last = m_settings->value("library/folder").toString();
    if (!last.isEmpty() && QDir(last).exists()) loadFolder(last);
}

void Library::setVisualizerEnabled(bool v) {
    if (m_visualizerEnabled == v) return;
    m_visualizerEnabled = v;
    m_settings->setValue("ui/visualizerEnabled", v);
    if (m_visualizer) m_visualizer->setEnabled(v);
    emit visualizerEnabledChanged();
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
    if (!m_rpc || !m_rpc->enabled()) return;

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
    m_settings->setValue("player/volume", v);
    emit volumeChanged();
}

void Library::setInfoPanelVisible(bool v) {
    if (m_infoPanelVisible == v) return;
    m_infoPanelVisible = v;
    m_settings->setValue("ui/infoPanelVisible", v);
    emit infoPanelVisibleChanged();
}

QString Library::formatDuration(qint64 ms) const {
    if (ms <= 0) return "--:--";
    const qint64 total = ms / 1000;
    return QString("%1:%2").arg(total / 60).arg(total % 60, 2, 10, QChar('0'));
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
#ifdef Q_OS_WIN
    const QString dir = kuteConfigDir() + "/covers";
#else
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
#endif
    QDir().mkpath(dir);
    return dir;
}

QString Library::thumbCacheDir() const {
#ifdef Q_OS_WIN
    const QString dir = kuteConfigDir() + "/thumbs";
#else
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/thumbs";
#endif
    QDir().mkpath(dir);
    return dir;
}

QString Library::lyricsDir() const {
    const QString dir = kuteConfigDir() + "/txts";
    QDir().mkpath(dir);
    return dir;
}

QString Library::lyricsPath(const Track &t, bool lrc) const {
    return lyricsDir() + "/" + safeFileName(t.title) + (lrc ? ".lrc" : ".txt");
}

QString Library::offsetsPath() const {
    return kuteConfigDir() + "/offsets.json";
}

QString Library::likedPath() const {
    return likedPathFor(m_folder);
}

QString Library::likedPathFor(const QString &folder) const {
    if (folder.isEmpty()) {
        return kuteConfigDir() + "/liked_orphan.json";
    }
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(folder.toUtf8(), QCryptographicHash::Sha1).toHex());
    return kuteConfigDir() + "/liked/" + hash + ".json";
}

QString Library::playlistOrderPath() const {
    return playlistOrderPathFor(m_folder);
}

QString Library::playlistOrderPathFor(const QString &folder) const {
    if (folder.isEmpty()) {
        return kuteConfigDir() + "/playlist_order_orphan.json";
    }
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(folder.toUtf8(), QCryptographicHash::Sha1).toHex());
    return kuteConfigDir() + "/playlist_order/" + hash + ".json";
}

QString Library::toFileUrl(const QString &localPath) const {
    if (localPath.isEmpty()) return {};
    return QUrl::fromLocalFile(localPath).toString();
}
QVariantList Library::searchGrouped(const QString &query) const {
    QVariantList groups;
    const QString q = query.trimmed().toLower();
    if (q.isEmpty()) return groups;

    QHash<QString, const Track*> byPath;
    byPath.reserve(m_allTracks.size());
    for (const Track &t : m_allTracks) byPath.insert(t.path, &t);

    auto trackToMap = [](const Track &t) {
        QVariantMap m;
        m["path"] = t.path;
        m["title"] = t.title;
        m["artist"] = t.artist;
        m["album"] = t.album;
        m["thumb"] = t.thumb;
        m["duration"] = t.durationMs;
        return m;
    };

    {
        QVariantList allTracks;
        for (const Track &t : m_allTracks) {
            if (t.title.toLower().contains(q) ||
                t.artist.toLower().contains(q) ||
                t.album.toLower().contains(q)) {
                allTracks.append(trackToMap(t));
            }
        }
        if (!allTracks.isEmpty()) {
            QVariantMap item;
            item["type"] = "all";
            item["id"] = "_all_";
            item["name"] = "All";
            item["cover"] = "";
            item["tracks"] = allTracks;
            QVariantList items;
            items.append(item);
            QVariantMap g;
            g["type"] = "all";
            g["title"] = "All";
            g["items"] = items;
            groups.append(g);
        }
    }

    {
        QVariantList items;
        for (const Playlist &p : m_playlists) {
            const bool nameMatch = p.name.toLower().contains(q);
            QVariantList tracks;
            for (const QString &path : p.tracks) {
                const Track *t = byPath.value(path, nullptr);
                if (!t) continue;
                const bool trackMatch = t->title.toLower().contains(q)
                                     || t->artist.toLower().contains(q)
                                     || t->album.toLower().contains(q);
                if (nameMatch || trackMatch) tracks.append(trackToMap(*t));
            }
            if (!tracks.isEmpty()) {
                QVariantMap m;
                m["type"] = "playlist";
                m["id"] = p.id;
                m["name"] = p.name;
                m["cover"] = p.cover;
                m["tracks"] = tracks;
                items.append(m);
            }
        }
        if (!items.isEmpty()) {
            QVariantMap g;
            g["type"] = "playlist";
            g["title"] = "Playlists";
            g["items"] = items;
            groups.append(g);
        }
    }

    {
        QMap<QString, QList<const Track*>> byArtist;
        for (const Track &t : m_allTracks) {
            if (t.artist.isEmpty() || t.artist == "Unknown Artist") continue;
            byArtist[t.artist].append(&t);
        }
        QVariantList items;
        for (auto it = byArtist.begin(); it != byArtist.end(); ++it) {
            const bool nameMatch = it.key().toLower().contains(q);
            QVariantList tracks;
            for (const Track *t : it.value()) {
                const bool trackMatch = t->title.toLower().contains(q)
                                     || t->artist.toLower().contains(q)
                                     || t->album.toLower().contains(q);
                if (nameMatch || trackMatch) tracks.append(trackToMap(*t));
            }
            if (!tracks.isEmpty()) {
                QVariantMap m;
                m["type"] = "artist";
                m["name"] = it.key();
                m["tracks"] = tracks;
                items.append(m);
            }
        }
        if (!items.isEmpty()) {
            QVariantMap g;
            g["type"] = "artist";
            g["title"] = "Artists";
            g["items"] = items;
            groups.append(g);
        }
    }

    {
        QMap<QString, QList<const Track*>> byAlbum;
        for (const Track &t : m_allTracks) {
            if (t.album.isEmpty() || t.album == "Unknown Album") continue;
            byAlbum[t.album].append(&t);
        }
        QVariantList items;
        for (auto it = byAlbum.begin(); it != byAlbum.end(); ++it) {
            const bool nameMatch = it.key().toLower().contains(q);
            QVariantList tracks;
            for (const Track *t : it.value()) {
                const bool trackMatch = t->title.toLower().contains(q)
                                     || t->artist.toLower().contains(q)
                                     || t->album.toLower().contains(q);
                if (nameMatch || trackMatch) tracks.append(trackToMap(*t));
            }
            if (!tracks.isEmpty()) {
                QVariantMap m;
                m["type"] = "album";
                m["name"] = it.key();
                m["tracks"] = tracks;
                items.append(m);
            }
        }
        if (!items.isEmpty()) {
            QVariantMap g;
            g["type"] = "album";
            g["title"] = "Albums";
            g["items"] = items;
            groups.append(g);
        }
    }

    return groups;
}

void Library::playTrackPath(const QString &path) {
    for (int i = 0; i < m_tracks.count(); ++i) {
        const Track *t = m_tracks.at(i);
        if (t && t->path == path) {
            playIndex(i);
            return;
        }
    }
    for (const Track &t : m_allTracks) {
        if (t.path == path) {
            m_currentIndex = -1;
            m_playbackPlaylistId.clear();
            startTrack(t);
            return;
        }
    }
}
