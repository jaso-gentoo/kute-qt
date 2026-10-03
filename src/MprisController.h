#pragma once

#include <QObject>
#include <QDBusAbstractAdaptor>
#include <QDBusObjectPath>
#include <QVariantMap>

class Library;

// ---------------- org.mpris.MediaPlayer2 ----------------
class MprisRootAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ canQuit CONSTANT)
    Q_PROPERTY(bool CanRaise READ canRaise CONSTANT)
    Q_PROPERTY(bool HasTrackList READ hasTrackList CONSTANT)
    Q_PROPERTY(QString Identity READ identity CONSTANT)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry CONSTANT)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supportedUriSchemes CONSTANT)
    Q_PROPERTY(QStringList SupportedMimeTypes READ supportedMimeTypes CONSTANT)

public:
    explicit MprisRootAdaptor(QObject *parent);

    bool canQuit() const { return true; }
    bool canRaise() const { return false; }
    bool hasTrackList() const { return false; }
    QString identity() const { return "kute"; }
    QString desktopEntry() const { return "kute"; }
    QStringList supportedUriSchemes() const { return {"file"}; }
    QStringList supportedMimeTypes() const;

public slots:
    void Raise() {}
    void Quit();
};

// ---------------- org.mpris.MediaPlayer2.Player ----------------
class MprisPlayerAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus NOTIFY playbackStatusChanged)
    Q_PROPERTY(QString LoopStatus READ loopStatus WRITE setLoopStatus NOTIFY loopStatusChanged)
    Q_PROPERTY(double Rate READ rate CONSTANT)
    Q_PROPERTY(bool Shuffle READ shuffle CONSTANT)
    Q_PROPERTY(QVariantMap Metadata READ metadata NOTIFY metadataChanged)
    Q_PROPERTY(double Volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(qlonglong Position READ position NOTIFY positionChanged)
    Q_PROPERTY(double MinimumRate READ minimumRate CONSTANT)
    Q_PROPERTY(double MaximumRate READ maximumRate CONSTANT)
    Q_PROPERTY(bool CanGoNext READ canGoNext CONSTANT)
    Q_PROPERTY(bool CanGoPrevious READ canGoPrevious CONSTANT)
    Q_PROPERTY(bool CanPlay READ canPlay CONSTANT)
    Q_PROPERTY(bool CanPause READ canPause CONSTANT)
    Q_PROPERTY(bool CanSeek READ canSeek CONSTANT)
    Q_PROPERTY(bool CanControl READ canControl CONSTANT)

public:
    // NOTE: parent передаётся сразу, без setParent после создания —
    // иначе QDBusAbstractAdaptor теряет привязку к MprisController.
    explicit MprisPlayerAdaptor(Library *lib, QObject *parent);

    QString playbackStatus() const;
    QString loopStatus() const;
    void    setLoopStatus(const QString &s);
    double  rate() const { return 1.0; }
    bool    shuffle() const { return false; }
    QVariantMap metadata() const;
    double  volume() const;
    void    setVolume(double v);
    qlonglong position() const;
    double  minimumRate() const { return 1.0; }
    double  maximumRate() const { return 1.0; }
    bool    canGoNext() const { return true; }
    bool    canGoPrevious() const { return true; }
    bool    canPlay() const { return true; }
    bool    canPause() const { return true; }
    bool    canSeek() const { return true; }
    bool    canControl() const { return true; }

public slots:
    void Next();
    void Previous();
    void Pause();
    void PlayPause();
    void Stop();
    void Play();
    void Seek(qlonglong offset);
    void SetPosition(const QDBusObjectPath &trackId, qlonglong position);
    void OpenUri(const QString &uri);

signals:
    void playbackStatusChanged();
    void loopStatusChanged();
    void metadataChanged();
    void volumeChanged();
    void positionChanged();
    void Seeked(qlonglong position);

private:
    Library *m_lib = nullptr;
};

// ---------------- Controller ----------------
class MprisController : public QObject {
    Q_OBJECT
public:
    explicit MprisController(Library *lib, QObject *parent = nullptr);
    ~MprisController();

private:
    Library *m_lib = nullptr;
    MprisRootAdaptor   *m_root = nullptr;
    MprisPlayerAdaptor *m_player = nullptr;
};