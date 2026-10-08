#include "AudioVisualizer.h"

#include <QMediaPlayer>
#include <QAudioBufferOutput>
#include <QAudioBuffer>
#include <QAudioFormat>
#include <QTimer>
#include <QDebug>
#include <cmath>

AudioVisualizer::AudioVisualizer(QMediaPlayer *player, QObject *parent)
    : QObject(parent), m_player(player) {

    for (int i = 0; i < kBars; ++i) {
        m_target.append(0.0f);
        m_current.append(0.0f);
        m_spectrum.append(0.0);
    }

    m_output = new QAudioBufferOutput(this);
    m_player->setAudioBufferOutput(m_output);

    connect(m_output, &QAudioBufferOutput::audioBufferReceived,
            this, &AudioVisualizer::onBufferReceived);

    m_timer = new QTimer(this);
    m_timer->setInterval(33);
    connect(m_timer, &QTimer::timeout, this, &AudioVisualizer::tick);
}

void AudioVisualizer::onBufferReceived(const QAudioBuffer &buffer) {
    static bool firstLog = true;
    if (firstLog) {
        firstLog = false;
        qDebug() << "AudioVisualizer: first buffer, valid:" << buffer.isValid()
                 << "frames:" << buffer.frameCount()
                 << "fmt:" << int(buffer.format().sampleFormat())
                 << "ch:" << buffer.format().channelCount()
                 << "rate:" << buffer.format().sampleRate();
    }
    if (!buffer.isValid()) return;

    const QAudioFormat fmt = buffer.format();
    const int channels = fmt.channelCount();
    const int frames = buffer.frameCount();
    if (frames <= 0 || channels <= 0) return;

    const double sr = fmt.sampleRate();
    if (sr <= 0) return;

    const int N = qMin(frames, 1024);

    auto sampleAt = [&](int i) -> double {
        switch (fmt.sampleFormat()) {
            case QAudioFormat::Int16: {
                const qint16 *d = buffer.constData<qint16>();
                return d[i * channels] / 32768.0;
            }
            case QAudioFormat::Int32: {
                const qint32 *d = buffer.constData<qint32>();
                return d[i * channels] / 2147483648.0;
            }
            case QAudioFormat::Float: {
                const float *d = buffer.constData<float>();
                return d[i * channels];
            }
            case QAudioFormat::UInt8: {
                const quint8 *d = buffer.constData<quint8>();
                return (int(d[i * channels]) - 128) / 128.0;
            }
            default:
                return 0.0;
        }
    };

    for (int b = 0; b < kBars; ++b) {
        const double t0 = double(b) / kBars;
        const double t1 = double(b + 1) / kBars;
        const double f0 = 60.0 * std::pow(8000.0 / 60.0, t0);
        const double f1 = 60.0 * std::pow(8000.0 / 60.0, t1);
        const double fc = (f0 + f1) * 0.5;
        if (fc >= sr * 0.5) continue;

        const double w = 2.0 * M_PI * fc / sr;
        const double coeff = 2.0 * std::cos(w);

        double s0 = 0.0, s1 = 0.0, s2 = 0.0;
        for (int i = 0; i < N; ++i) {
            const double x = sampleAt(i);
            s0 = x + coeff * s1 - s2;
            s2 = s1;
            s1 = s0;
        }

        double mag = s1 * s1 + s2 * s2 - coeff * s1 * s2;
        if (mag < 0) mag = 0;
        float amplitude = float(std::sqrt(mag)) / N;
        amplitude = std::log10(1.0f + 40.0f * amplitude) * 1.3f;
        if (amplitude > m_target[b]) m_target[b] = amplitude;
    }

    if (!m_timer->isActive()) m_timer->start();
}

void AudioVisualizer::tick() {
    bool changed = false;

    for (int i = 0; i < kBars; ++i) {
        const float target = m_target[i];
        if (target > m_current[i]) {
            m_current[i] = target;
        } else {
            m_current[i] = m_current[i] * 0.72f + target * 0.28f;
        }

        const double v = qBound(0.0, double(m_current[i]), 1.0);
        if (std::abs(v - m_spectrum[i].toDouble()) > 0.008) {
            m_spectrum[i] = v;
            changed = true;
        }

        m_target[i] *= 0.55f;
    }

    if (changed) {
        static bool firstEmit = true;
        if (firstEmit) { firstEmit = false; qDebug() << "AudioVisualizer: first spectrum emit"; }
        emit spectrumChanged();
    }
}