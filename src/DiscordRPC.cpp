#include "DiscordRPC.h"

#include <QTimer>
#include <QJsonDocument>
#include <QJsonValue>
#include <QFile>
#include <QDateTime>
#include <QCoreApplication>
#include <QSettings>
#include <QAtomicInteger>

static QAtomicInteger<quint64> g_nonce{1};

DiscordRPC::DiscordRPC(QObject *parent) : QObject(parent) {
    QSettings s;
    m_enabled = s.value("discord/enabled", true).toBool();

    m_socket = new QLocalSocket(this);

    m_reconnectTimer = new QTimer(this);
    m_reconnectTimer->setSingleShot(true);
    m_reconnectTimer->setInterval(5000);

    m_throttleTimer = new QTimer(this);
    m_throttleTimer->setSingleShot(true);

    connect(m_reconnectTimer, &QTimer::timeout, this, &DiscordRPC::tryConnect);
    connect(m_throttleTimer, &QTimer::timeout, this, &DiscordRPC::processQueue);
    connect(m_socket, &QLocalSocket::connected, this, &DiscordRPC::onConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &DiscordRPC::onDisconnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &DiscordRPC::onReadyRead);
    connect(m_socket, &QLocalSocket::errorOccurred,
            this, [this](QLocalSocket::LocalSocketError) {
        m_connected = false;
        m_handshakeDone = false;
        emit connectedChanged();
    });

    if (m_enabled) tryConnect();
}

DiscordRPC::~DiscordRPC() {
    if (m_socket->state() == QLocalSocket::ConnectedState)
        m_socket->disconnectFromServer();
}

void DiscordRPC::setEnabled(bool v) {
    if (m_enabled == v) return;
    m_enabled = v;
    QSettings().setValue("discord/enabled", v);

    if (v) {
        m_attemptIndex = 0;
        m_passIndex = 0;
        tryConnect();
    } else {
        m_hasPendingFrame = false;
        m_sendHistory.clear();
        m_throttleTimer->stop();
        if (m_connected && m_handshakeDone) {
            QJsonObject args;
            args["pid"] = (double)QCoreApplication::applicationPid();
            args["activity"] = QJsonValue::Null;
            QJsonObject frame;
            frame["cmd"] = "SET_ACTIVITY";
            frame["args"] = args;
            frame["nonce"] = QString::number(g_nonce.fetchAndAddRelaxed(1));
            sendFrameTracked(frame);
        }
        m_socket->abort();
        m_connected = false;
        m_handshakeDone = false;
        emit connectedChanged();
    }
    emit enabledChanged();
}

void DiscordRPC::tryConnect() {
    if (!m_enabled) return;
    if (m_socket->state() != QLocalSocket::UnconnectedState) return;

#ifdef Q_OS_WIN
    // Windows: \\.\pipe\discord-ipc-N
    if (m_attemptIndex >= 10) {
        m_attemptIndex = 0;
        m_reconnectTimer->start();
        return;
    }

    const QString path = QString("\\\\.\\pipe\\discord-ipc-%1").arg(m_attemptIndex);
    m_socket->connectToServer(path);

    QTimer::singleShot(100, this, [this]() {
        if (m_socket->state() == QLocalSocket::UnconnectedState) {
            m_attemptIndex++;
            tryConnect();
        }
    });
#else
    const QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");

    QStringList dirs;
    if (!runtimeDir.isEmpty()) dirs << runtimeDir;
    dirs << "/tmp" << "/var/run";

    if (m_attemptIndex >= 10) {
        m_attemptIndex = 0;
        m_passIndex++;
        if (m_passIndex < 3) {
            QTimer::singleShot(500, this, &DiscordRPC::tryConnect);
        } else {
            m_passIndex = 0;
            m_reconnectTimer->start();
        }
        return;
    }

    for (const QString &dir : dirs) {
        const QString path = QString("%1/discord-ipc-%2").arg(dir).arg(m_attemptIndex);
        if (QFile::exists(path)) {
            m_socket->connectToServer(path);
            return;
        }
    }

    m_attemptIndex++;
    QTimer::singleShot(20, this, &DiscordRPC::tryConnect);
#endif
}

void DiscordRPC::onConnected() {
    m_connected = true;
    m_handshakeDone = false;
    emit connectedChanged();
    sendHandshake();
}

void DiscordRPC::onDisconnected() {
    m_connected = false;
    m_handshakeDone = false;
    emit connectedChanged();
    m_attemptIndex = 0;
    m_passIndex = 0;
    m_reconnectTimer->start();
}

void DiscordRPC::sendHandshake() {
    QJsonObject handshake;
    handshake["v"] = 1;
    handshake["client_id"] = m_clientId;
    sendPacket(0, handshake);
}

void DiscordRPC::sendFrameTracked(const QJsonObject &payload) {
    sendPacket(1, payload);
    m_sendHistory.enqueue(QDateTime::currentMSecsSinceEpoch());
}

void DiscordRPC::sendPacket(int opcode, const QJsonObject &payload) {
    if (m_socket->state() != QLocalSocket::ConnectedState) return;

    const QByteArray json = QJsonDocument(payload).toJson(QJsonDocument::Compact);

    QByteArray packet;
    packet.reserve(8 + json.size());
    packet.append(char(opcode & 0xFF));
    packet.append(char((opcode >> 8) & 0xFF));
    packet.append(char((opcode >> 16) & 0xFF));
    packet.append(char((opcode >> 24) & 0xFF));

    const int len = json.size();
    packet.append(char(len & 0xFF));
    packet.append(char((len >> 8) & 0xFF));
    packet.append(char((len >> 16) & 0xFF));
    packet.append(char((len >> 24) & 0xFF));
    packet.append(json);

    m_socket->write(packet);
    m_socket->flush();
}

void DiscordRPC::onReadyRead() {
    while (m_socket->bytesAvailable() >= 8) {
        const QByteArray header = m_socket->peek(8);
        if (header.size() < 8) break;

        const int opcode = (uchar)header[0]
                         | ((uchar)header[1] << 8)
                         | ((uchar)header[2] << 16)
                         | ((uchar)header[3] << 24);
        const int len = (uchar)header[4]
                      | ((uchar)header[5] << 8)
                      | ((uchar)header[6] << 16)
                      | ((uchar)header[7] << 24);

        if (m_socket->bytesAvailable() < 8 + len) break;

        m_socket->read(8);
        const QByteArray payload = m_socket->read(len);

        if (opcode == 1) {
            const QJsonDocument doc = QJsonDocument::fromJson(payload);
            if (doc.isObject()) {
                const QJsonObject obj = doc.object();
                if (obj.value("evt").toString() == "READY") {
                    m_handshakeDone = true;
                    if (m_hasPendingFrame) processQueue();
                }
            }
        }
    }
}

void DiscordRPC::sendOrQueue(const QJsonObject &frame) {
    m_pendingFrame = frame;
    m_hasPendingFrame = true;

    if (!m_enabled) return;
    if (!m_connected || !m_handshakeDone) {
        if (m_socket->state() == QLocalSocket::UnconnectedState) tryConnect();
        return;
    }

    processQueue();
}

void DiscordRPC::processQueue() {
    if (!m_hasPendingFrame) return;
    if (!m_connected || !m_handshakeDone) return;

    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    while (!m_sendHistory.isEmpty() && (now - m_sendHistory.head()) > kWindowMs)
        m_sendHistory.dequeue();

    if (m_sendHistory.size() < kMaxRequests) {
        sendFrameTracked(m_pendingFrame);
        m_hasPendingFrame = false;
        return;
    }

    const qint64 oldest = m_sendHistory.head();
    const qint64 waitMs = (oldest + kWindowMs) - now + 30;
    if (waitMs > 0 && !m_throttleTimer->isActive()) {
        m_throttleTimer->start(int(waitMs));
    }
}

void DiscordRPC::setActivity(const QString &details,
                             const QString &state,
                             qint64 startTimestamp) {
    if (!m_enabled) return;

    QJsonObject activity;
    activity["details"] = details;
    if (!state.isEmpty()) activity["state"] = state;
    activity["type"] = 2;

    if (startTimestamp > 0) {
        QJsonObject ts;
        ts["start"] = (double)startTimestamp;
        activity["timestamps"] = ts;
    }

    QJsonObject args;
    args["pid"] = (double)QCoreApplication::applicationPid();
    args["activity"] = activity;

    QJsonObject frame;
    frame["cmd"] = "SET_ACTIVITY";
    frame["args"] = args;
    frame["nonce"] = QString::number(g_nonce.fetchAndAddRelaxed(1));

    sendOrQueue(frame);
}

void DiscordRPC::clearActivity() {
    if (!m_enabled) return;

    QJsonObject args;
    args["pid"] = (double)QCoreApplication::applicationPid();
    args["activity"] = QJsonValue::Null;

    QJsonObject frame;
    frame["cmd"] = "SET_ACTIVITY";
    frame["args"] = args;
    frame["nonce"] = QString::number(g_nonce.fetchAndAddRelaxed(1));

    sendOrQueue(frame);
}