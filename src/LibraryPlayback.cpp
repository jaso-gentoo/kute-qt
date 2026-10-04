#include "Library.h"
#include "LibraryInternal.h"

#include <QUrl>
#include <QThread>
#include <QMetaObject>
#include <memory>

void Library::restorePlayer(const QString &path, qint64 savedPos, bool wasPlaying) {
    m_player->setSource(QUrl::fromLocalFile(path));

    if (savedPos <= 0 && !wasPlaying) return;

    auto applyPosition = [this, savedPos, wasPlaying]() {
        if (savedPos > 0)
            m_player->setPosition(savedPos);
        if (wasPlaying) {
            m_intentPlaying = true;
            m_player->play();
            schedulePresence();
        }
    };

    const auto st = m_player->mediaStatus();
    if (st == QMediaPlayer::LoadedMedia || st == QMediaPlayer::BufferedMedia) {
        applyPosition();
        return;
    }

    auto conn = std::make_shared<QMetaObject::Connection>();
    *conn = connect(m_player, &QMediaPlayer::mediaStatusChanged, this,
        [this, conn, applyPosition](QMediaPlayer::MediaStatus st) {
            if (st == QMediaPlayer::LoadedMedia || st == QMediaPlayer::BufferedMedia) {
                QObject::disconnect(*conn);
                applyPosition();
            } else if (st == QMediaPlayer::EndOfMedia
                    || st == QMediaPlayer::InvalidMedia
                    || st == QMediaPlayer::NoMedia) {
                QObject::disconnect(*conn);
            }
        });
}

void Library::startTrack(const Track &t) {
    m_currentTrack = t;
    m_intentPlaying = true;
    m_player->setSource(QUrl::fromLocalFile(t.path));

#ifdef Q_OS_WIN
    m_pendingPlay = true;
    m_playRetries = 0;
    m_expectedDuration = t.durationMs;
#else
    m_pendingPlay = false;
    m_playRetries = 0;
    m_expectedDuration = 0;
    m_player->play();
#endif

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
        m_pendingPlay = false;
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

void Library::cycleRepeat() {
    m_repeatMode = (m_repeatMode + 1) % 3;
    m_settings->setValue("player/repeatMode", m_repeatMode);
    emit repeatModeChanged();
}