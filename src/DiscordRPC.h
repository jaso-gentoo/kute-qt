#pragma once

#include <QObject>
#include <QLocalSocket>
#include <QJsonObject>
#include <QQueue>

class QTimer;

class DiscordRPC : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool enabled   READ enabled   WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit DiscordRPC(QObject *parent = nullptr);
    ~DiscordRPC();

    bool connected() const { return m_connected; }
    bool enabled()   const { return m_enabled; }
    void setEnabled(bool v);

    void setActivity(const QString &details,
                     const QString &state,
                     qint64 startTimestamp = 0);
    void clearActivity();

signals:
    void connectedChanged();
    void enabledChanged();

private:
    void tryConnect();
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void sendHandshake();
    void sendPacket(int opcode, const QJsonObject &payload);
    void sendFrameTracked(const QJsonObject &payload);
    void sendOrQueue(const QJsonObject &frame);
    void processQueue();

    QLocalSocket *m_socket = nullptr;
    QTimer       *m_reconnectTimer = nullptr;
    QTimer       *m_throttleTimer = nullptr;

    QString       m_clientId = "1488264103607926834";
    bool          m_connected = false;
    bool          m_enabled = true;
    bool          m_handshakeDone = false;

    QJsonObject   m_pendingFrame;
    bool          m_hasPendingFrame = false;

    QQueue<qint64> m_sendHistory;

    int           m_attemptIndex = 0;
    int           m_passIndex = 0;

    QString       m_lastDetails;
    QString       m_lastState;
    qint64        m_lastStart = 0;
    bool          m_hasLastActivity = false;
    bool          m_hasLastCleared = false;

    static constexpr int    kMaxRequests = 5;
    static constexpr qint64 kWindowMs    = 20000;
};