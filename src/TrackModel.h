#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>

struct Track {
    QString path;
    QString title;
    QString artist;
    QString album;
    QString cover;
    QString thumb;
    qint64 durationMs = 0;
    QString format;
    int bitrate = 0;
    int sampleRate = 0;
    int channels = 0;
    int year = 0;
    qint64 fileSize = 0;
};

class TrackModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        PathRole = Qt::UserRole + 1,
        TitleRole,
        ArtistRole,
        AlbumRole,
        CoverRole,
        ThumbRole,
        DurationRole,
        FormatRole,
        BitrateRole,
        SampleRateRole,
        ChannelsRole,
        YearRole,
        FileSizeRole
    };

    explicit TrackModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setTracks(const QList<Track> &tracks);
    void setTracksAnimated(const QList<Track> &tracks);
    void updateFiltered(const QList<Track> &newTracks);
    void moveRow(int from, int to);
    void updateTrack(int index, const Track &t);
    bool removeByPath(const QString &path);
    void clear();
    int count() const { return m_tracks.size(); }
    const Track *at(int i) const;
    Track *atMutable(int i);

signals:
    void countChanged();

private:
    QList<Track> m_tracks;
};