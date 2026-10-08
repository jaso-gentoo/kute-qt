#pragma once

#include <QObject>
#include <QList>
#include <QVariantList>

class QMediaPlayer;
class QAudioBufferOutput;
class QAudioBuffer;
class QTimer;

class AudioVisualizer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY spectrumChanged)

public:
    explicit AudioVisualizer(QMediaPlayer *player, QObject *parent = nullptr);

    QVariantList spectrum() const { return m_spectrum; }

signals:
    void spectrumChanged();

private:
    void onBufferReceived(const QAudioBuffer &buffer);
    void tick();

    QMediaPlayer *m_player = nullptr;
    QAudioBufferOutput *m_output = nullptr;
    QTimer *m_timer = nullptr;

    QVariantList m_spectrum;
    QList<float> m_target;
    QList<float> m_current;
    bool m_active = false;

    static constexpr int kBars = 32;
};