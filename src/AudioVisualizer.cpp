#include "AudioVisualizer.h"

#include <QMediaPlayer>
#include <QAudioBufferOutput>
#include <QAudioBuffer>
#include <QAudioFormat>
#include <QTimer>
#include <QDebug>
#include <cmath>
#include <algorithm>
#include <utility>

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

void AudioVisualizer::setEnabled(bool v) {
    if (m_enabled == v) return;
    m_enabled = v;
    if (!v) {
        for (int i = 0; i < kBars; ++i) {
            m_target[i] = 0.0f;
            m_current[i] = 0.0f;
            m_spectrum[i] = 0.0;
        }
        m_timer->stop();
        emit spectrumChanged();
    }
}

void AudioVisualizer::onBufferReceived(const QAudioBuffer &buffer) {
    if (!m_enabled) return;
    if (!buffer.isValid()) return;

    if ((++m_skipCounter & 1) == 0) return;

    const QAudioFormat fmt = buffer.format();
    const int channels = fmt.channelCount();
    const int frames = buffer.frameCount();
    if (frames <= 0 || channels <= 0) return;

    const double sr = fmt.sampleRate();
    if (sr <= 0) return;

    constexpr int N = 1024;
    if (frames < N / 4) return;

    auto sampleAt = [&](int i) -> float {
        switch (fmt.sampleFormat()) {
            case QAudioFormat::Int16:
                return buffer.constData<qint16>()[i * channels] / 32768.0f;
            case QAudioFormat::Int32:
                return buffer.constData<qint32>()[i * channels] / 2147483648.0f;
            case QAudioFormat::Float:
                return buffer.constData<float>()[i * channels];
            case QAudioFormat::UInt8:
                return (int(buffer.constData<quint8>()[i * channels]) - 128) / 128.0f;
            default:
                return 0.0f;
        }
    };

    constexpr float kPi = 3.14159265358979323846f;

    float re[N], im[N];
    for (int i = 0; i < N; ++i) {
        const float x = (i < frames) ? sampleAt(i) : 0.0f;
        const float w = 0.5f - 0.5f * std::cos(2.0f * kPi * i / float(N - 1));
        re[i] = x * w;
        im[i] = 0.0f;
    }

    for (int i = 1, j = 0; i < N; ++i) {
        int bit = N >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) {
            std::swap(re[i], re[j]);
            std::swap(im[i], im[j]);
        }
    }
    for (int len = 2; len <= N; len <<= 1) {
        const float ang = -2.0f * kPi / float(len);
        const float wR0 = std::cos(ang);
        const float wI0 = std::sin(ang);
        for (int i = 0; i < N; i += len) {
            float wR = 1.0f, wI = 0.0f;
            for (int j = 0; j < len / 2; ++j) {
                const float uR = re[i + j];
                const float uI = im[i + j];
                const float tR = re[i + j + len / 2];
                const float tI = im[i + j + len / 2];
                const float vR = tR * wR - tI * wI;
                const float vI = tR * wI + tI * wR;
                re[i + j]           = uR + vR;
                im[i + j]           = uI + vI;
                re[i + j + len / 2] = uR - vR;
                im[i + j + len / 2] = uI - vI;
                const float nwR = wR * wR0 - wI * wI0;
                const float nwI = wR * wI0 + wI * wR0;
                wR = nwR;
                wI = nwI;
            }
        }
    }

    const int nb = N / 2;
    for (int b = 0; b < kBars; ++b) {
        const double t0 = double(b) / kBars;
        const double t1 = double(b + 1) / kBars;
        const double f0 = 60.0 * std::pow(8000.0 / 60.0, t0);
        const double f1 = 60.0 * std::pow(8000.0 / 60.0, t1);

        int k0 = int(std::floor(f0 * N / sr));
        int k1 = int(std::ceil (f1 * N / sr));
        if (k0 < 1) k0 = 1;
        if (k1 > nb - 1) k1 = nb - 1;
        if (k1 < k0) continue;

        float peak = 0.0f;
        for (int k = k0; k <= k1; ++k) {
            const float mag = std::sqrt(re[k] * re[k] + im[k] * im[k]);
            if (mag > peak) peak = mag;
        }

        float amplitude = peak / float(N);
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

    if (changed) emit spectrumChanged();
}