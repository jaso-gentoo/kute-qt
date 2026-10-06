#include "Library.h"
#include "LibraryInternal.h"

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

    loadOffsets();

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

void Library::setShowOnlyLiked(bool v) {
    if (m_showOnlyLiked == v) return;
    m_showOnlyLiked = v;
    sortAndApply(false);
    emit showOnlyLikedChanged();
    emit currentChanged();
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
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
    QDir().mkpath(dir);
    return dir;
}

QString Library::thumbCacheDir() const {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/thumbs";
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