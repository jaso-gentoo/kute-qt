#pragma once

#include <QObject>
#include <QList>
#include <QVariantList>
#include <QMap>

class QMediaPlayer;
class QAudioBufferOutput;
class QAudioBuffer;
class QAudioDecoder;
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
    void computeSpectrum(const QAudioBuffer &buffer, QList<float> &out);

#ifdef Q_OS_WIN
    void onDecoderBuffer();
    void resetDecoder(const QUrl &source);
#endif

    QMediaPlayer *m_player = nullptr;
    QAudioBufferOutput *m_output = nullptr;
    QTimer *m_timer = nullptr;

    QVariantList m_spectrum;
    QList<float> m_target;
    QList<float> m_current;

#ifdef Q_OS_WIN
    QAudioDecoder *m_decoder = nullptr;
    QMap<qint64, QList<float>> m_frames;
    qint64 m_lastDecodedEnd = 0;
#endif

    static constexpr int kBars = 32;
};