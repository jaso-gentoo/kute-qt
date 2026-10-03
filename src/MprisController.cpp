#include "MprisController.h"
#include "Library.h"

#include <QDBusConnection>
#include <QDBusError>
#include <QCoreApplication>
#include <QUrl>
#include <QDebug>
#include <QDBusConnectionInterface>

static const char *kObjectPath = "/org/mpris/MediaPlayer2";
static const char *kService    = "org.mpris.MediaPlayer2.kute";

// ---------------- MprisRootAdaptor ----------------

MprisRootAdaptor::MprisRootAdaptor(QObject *parent) : QDBusAbstractAdaptor(parent) {
    setAutoRelaySignals(true);
}

QStringList MprisRootAdaptor::supportedMimeTypes() const {
    return {"audio/mpeg", "audio/flac", "audio/ogg", "audio/opus",
            "audio/wav", "audio/mp4", "audio/aac"};
}

void MprisRootAdaptor::Quit() {
    QCoreApplication::quit();
}

// ---------------- MprisPlayerAdaptor ----------------

MprisPlayerAdaptor::MprisPlayerAdaptor(Library *lib, QObject *parent)
    : QDBusAbstractAdaptor(parent), m_lib(lib) {
    setAutoRelaySignals(true);

    connect(lib, &Library::isPlayingChanged,  this, &MprisPlayerAdaptor::playbackStatusChanged);
    connect(lib, &Library::currentChanged,    this, &MprisPlayerAdaptor::metadataChanged);
    connect(lib, &Library::currentChanged,    this, &MprisPlayerAdaptor::playbackStatusChanged);
    connect(lib, &Library::volumeChanged,     this, &MprisPlayerAdaptor::volumeChanged);
    connect(lib, &Library::positionChanged,   this, &MprisPlayerAdaptor::positionChanged);
    connect(lib, &Library::repeatModeChanged, this, &MprisPlayerAdaptor::loopStatusChanged);
}

QString MprisPlayerAdaptor::playbackStatus() const {
    if (!m_lib) return "Stopped";
    if (m_lib->isPlaying()) return "Playing";
    if (m_lib->hasCurrent()) return "Paused";
    return "Stopped";
}

QString MprisPlayerAdaptor::loopStatus() const {
    if (!m_lib) return "None";
    switch (m_lib->repeatMode()) {
        case 1: return "Playlist";
        case 2: return "Track";
        default: return "None";
    }
}

void MprisPlayerAdaptor::setLoopStatus(const QString &s) {
    if (!m_lib) return;
    int want = 0;
    if (s == "Playlist") want = 1;
    else if (s == "Track") want = 2;
    else want = 0;
    while (m_lib->repeatMode() != want) m_lib->cycleRepeat();
}

QVariantMap MprisPlayerAdaptor::metadata() const {
    QVariantMap m;
    if (!m_lib || !m_lib->hasCurrent()) {
        m["mpris:trackid"] = QVariant::fromValue(
            QDBusObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack"));
        return m;
    }

    const QString path = m_lib->currentFilePath();
    const QString trackId = "/org/mpris/MediaPlayer2/Track/" +
        QString::number(qHash(path));

    m["mpris:trackid"] = QVariant::fromValue(QDBusObjectPath(trackId));
    m["xesam:title"]   = m_lib->currentTitle();
    m["xesam:artist"]  = QStringList{m_lib->currentArtist()};
    m["xesam:album"]   = m_lib->currentAlbum();
    m["mpris:length"]  = static_cast<qlonglong>(m_lib->currentTrackDuration()) * 1000;
    m["xesam:url"]     = QUrl::fromLocalFile(path).toString();
    if (!m_lib->currentCover().isEmpty())
        m["mpris:artUrl"] = QUrl::fromLocalFile(m_lib->currentCover()).toString();
    return m;
}

double MprisPlayerAdaptor::volume() const {
    if (!m_lib) return 0.0;
    return m_lib->volume() / 100.0;
}

void MprisPlayerAdaptor::setVolume(double v) {
    if (!m_lib) return;
    m_lib->setVolume(int(v * 100.0));
}

qlonglong MprisPlayerAdaptor::position() const {
    if (!m_lib) return 0;
    return m_lib->position() * 1000;
}

void MprisPlayerAdaptor::Next()      { if (m_lib) m_lib->next(); }
void MprisPlayerAdaptor::Previous()  { if (m_lib) m_lib->prev(); }
void MprisPlayerAdaptor::Pause()     { if (m_lib && m_lib->isPlaying()) m_lib->togglePlayPause(); }
void MprisPlayerAdaptor::Play()      { if (m_lib && !m_lib->isPlaying()) m_lib->togglePlayPause(); }
void MprisPlayerAdaptor::PlayPause() { if (m_lib) m_lib->togglePlayPause(); }
void MprisPlayerAdaptor::Stop()      { if (m_lib && m_lib->isPlaying()) m_lib->togglePlayPause(); }
void MprisPlayerAdaptor::OpenUri(const QString &) {}

void MprisPlayerAdaptor::Seek(qlonglong offset) {
    if (!m_lib) return;
    const qlonglong cur = m_lib->position() * 1000;
    qlonglong next = cur + offset;
    if (next < 0) next = 0;
    m_lib->seek(next / 1000);
    emit Seeked(next);
}

void MprisPlayerAdaptor::SetPosition(const QDBusObjectPath &, qlonglong position) {
    if (!m_lib) return;
    if (position < 0) position = 0;
    m_lib->seek(position / 1000);
    emit Seeked(position);
}

// ---------------- MprisController ----------------

MprisController::MprisController(Library *lib, QObject *parent)
    : QObject(parent), m_lib(lib) {

    // ВАЖНО: оба адаптера — прямые дети MprisController, без setParent после создания.
    m_root   = new MprisRootAdaptor(this);
    m_player = new MprisPlayerAdaptor(lib, this);

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning() << "MPRIS: session D-Bus not available:" << bus.lastError().message();
        return;
    }

    const auto flags = QDBusConnection::ExportAdaptors
                     | QDBusConnection::ExportAllProperties
                     | QDBusConnection::ExportAllSignals
                     | QDBusConnection::ExportAllInvokables;

    if (!bus.registerObject(kObjectPath, this, flags)) {
        qWarning() << "MPRIS: registerObject failed:" << bus.lastError().message();
    }

    // Если имя уже занято (например, упавший прошлый процесс), попробуем его освободить.
    if (bus.interface()) {
        const auto owners = bus.interface()->registeredServiceNames().value();
        if (owners.contains(kService)) {
            qInfo() << "MPRIS: service" << kService << "already taken, releasing";
            bus.interface()->unregisterService(kService);
        }
    }

    if (!bus.registerService(kService)) {
        qWarning() << "MPRIS: registerService failed:" << bus.lastError().message();
    } else {
        qInfo() << "MPRIS: registered service" << kService << "on" << kObjectPath;
    }
}

MprisController::~MprisController() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) return;
    bus.unregisterService(kService);
    bus.unregisterObject(kObjectPath);
}