#include "AudioVisualizer.h"

#include <QMediaPlayer>
#include <QAudioBufferOutput>
#include <QAudioBuffer>
#include <QAudioFormat>
#include <QTimer>
#include <QDebug>
#include <cmath>

#ifdef Q_OS_WIN
#include <QAudioDecoder>
#endif

AudioVisualizer::AudioVisualizer(QMediaPlayer *player, QObject *parent)
    : QObject(parent), m_player(player) {

    for (int i = 0; i < kBars; ++i) {
        m_target.append(0.0f);
        m_current.append(0.0f);
        m_spectrum.append(0.0);
    }

#ifndef Q_OS_WIN
    m_output = new QAudioBufferOutput(this);
    m_player->setAudioBufferOutput(m_output);

    connect(m_output, &QAudioBufferOutput::audioBufferReceived,
            this, &AudioVisualizer::onBufferReceived);
#endif

    m_timer = new QTimer(this);
    m_timer->setInterval(33);
    connect(m_timer, &QTimer::timeout, this, &AudioVisualizer::tick);

#ifdef Q_OS_WIN
    connect(m_player, &QMediaPlayer::sourceChanged, this, [this](const QUrl &url) {
        resetDecoder(url);
    });

    if (!m_player->source().isEmpty()) resetDecoder(m_player->source());
#endif
}

void AudioVisualizer::computeSpectrum(const QAudioBuffer &buffer, QList<float> &out) {
    out.clear();
    out.resize(kBars);
    for (int i = 0; i < kBars; ++i) out[i] = 0.0f;

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
        out[b] = amplitude;
    }
}

#ifndef Q_OS_WIN

void AudioVisualizer::onBufferReceived(const QAudioBuffer &buffer) {
    if (!buffer.isValid()) return;

    QList<float> spectrum;
    computeSpectrum(buffer, spectrum);

    for (int b = 0; b < kBars; ++b) {
        if (spectrum[b] > m_target[b]) m_target[b] = spectrum[b];
    }

    if (!m_timer->isActive()) m_timer->start();
}

#endif

#ifdef Q_OS_WIN

void AudioVisualizer::resetDecoder(const QUrl &source) {
    if (m_decoder) {
        m_decoder->stop();
        m_decoder->deleteLater();
        m_decoder = nullptr;
    }

    m_frames.clear();
    m_lastDecodedEnd = 0;

    for (int i = 0; i < kBars; ++i) {
        m_target[i] = 0.0f;
        m_current[i] = 0.0f;
    }

    if (source.isEmpty()) return;

    m_decoder = new QAudioDecoder(this);
    m_decoder->setSource(source);

    connect(m_decoder, &QAudioDecoder::bufferReady, this, &AudioVisualizer::onDecoderBuffer);
    connect(m_decoder, &QAudioDecoder::errorOccurred, this, [this](QAudioDecoder::Error) {
        qWarning() << "AudioVisualizer: decoder error" << m_decoder->errorString();
    });

    m_decoder->start();

    if (!m_timer->isActive()) m_timer->start();
}

void AudioVisualizer::onDecoderBuffer() {
    if (!m_decoder) return;

    QAudioBuffer buffer = m_decoder->read();
    if (!buffer.isValid()) return;

    const qint64 startMs = buffer.startTime() / 1000;
    const qint64 durMs = buffer.duration() / 1000;
    if (durMs <= 0) return;

    QList<float> spectrum;
    computeSpectrum(buffer, spectrum);

    m_frames.insert(startMs, spectrum);
    m_lastDecodedEnd = startMs + durMs;

    if (m_frames.size() > 8000) {
        auto it = m_frames.begin();
        for (int i = 0; i < 2000 && it != m_frames.end(); ++i) {
            it = m_frames.erase(it);
        }
    }
}

#endif

void AudioVisualizer::tick() {
    bool changed = false;

#ifdef Q_OS_WIN
    if (m_decoder && m_player->playbackState() == QMediaPlayer::PlayingState && !m_frames.isEmpty()) {
        const qint64 pos = m_player->position();
        auto it = m_frames.upperBound(pos);
        if (it != m_frames.begin()) {
            --it;
            const QList<float> &frame = it.value();
            for (int i = 0; i < kBars; ++i) {
                if (frame[i] > m_target[i]) m_target[i] = frame[i];
            }
        }
    }

    if (m_decoder
        && m_decoder->isDecoding()
        && !m_frames.isEmpty()
        && m_player->playbackState() == QMediaPlayer::PlayingState) {
        const qint64 pos = m_player->position();
        const qint64 ahead = m_lastDecodedEnd - pos;
        if (ahead < 3000 && m_decoder->isDecoding()) {
        }
    }
#endif

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