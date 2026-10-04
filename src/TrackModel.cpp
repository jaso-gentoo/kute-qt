#include "TrackModel.h"
#include <QSet>

TrackModel::TrackModel(QObject *parent) : QAbstractListModel(parent) {}

int TrackModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_tracks.size();
}

QVariant TrackModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_tracks.size()) return {};
    const Track &t = m_tracks[index.row()];
    switch (role) {
        case PathRole:       return t.path;
        case TitleRole:      return t.title;
        case ArtistRole:     return t.artist;
        case AlbumRole:      return t.album;
        case CoverRole:      return t.cover;
        case ThumbRole:      return t.thumb;
        case DurationRole:   return t.durationMs;
        case FormatRole:     return t.format;
        case BitrateRole:    return t.bitrate;
        case SampleRateRole: return t.sampleRate;
        case ChannelsRole:   return t.channels;
        case YearRole:       return t.year;
        case FileSizeRole:   return t.fileSize;
    }
    return {};
}

QHash<int, QByteArray> TrackModel::roleNames() const {
    return {
        { PathRole,       "path" },
        { TitleRole,      "title" },
        { ArtistRole,     "artist" },
        { AlbumRole,      "album" },
        { CoverRole,      "cover" },
        { ThumbRole,      "thumb" },
        { DurationRole,   "duration" },
        { FormatRole,     "format" },
        { BitrateRole,    "bitrate" },
        { SampleRateRole, "sampleRate" },
        { ChannelsRole,   "channels" },
        { YearRole,       "year" },
        { FileSizeRole,   "fileSize" }
    };
}

void TrackModel::setTracks(const QList<Track> &tracks) {
    beginResetModel();
    m_tracks = tracks;
    endResetModel();
    emit countChanged();
}

void TrackModel::setTracksAnimated(const QList<Track> &newTracks) {
    int commonPrefix = 0;
    const int minSize = qMin(m_tracks.size(), newTracks.size());
    while (commonPrefix < minSize
           && m_tracks[commonPrefix].path == newTracks[commonPrefix].path) {
        ++commonPrefix;
    }
    const int changes = qMax(m_tracks.size(), newTracks.size()) - commonPrefix;
    if (changes > 20) {
        setTracks(newTracks);
        return;
    }

    QSet<QString> newPaths;
    newPaths.reserve(newTracks.size());
    for (const auto &t : newTracks) newPaths.insert(t.path);

    for (int i = m_tracks.size() - 1; i >= 0; --i) {
        if (!newPaths.contains(m_tracks[i].path)) {
            beginRemoveRows(QModelIndex(), i, i);
            m_tracks.removeAt(i);
            endRemoveRows();
        }
    }

    for (int i = 0; i < newTracks.size(); ++i) {
        const Track &nt = newTracks[i];
        int curIdx = -1;
        for (int j = i; j < m_tracks.size(); ++j) {
            if (m_tracks[j].path == nt.path) { curIdx = j; break; }
        }

        if (curIdx < 0) {
            beginInsertRows(QModelIndex(), i, i);
            m_tracks.insert(i, nt);
            endInsertRows();
        } else if (curIdx > i) {
            beginMoveRows(QModelIndex(), curIdx, curIdx, QModelIndex(), i);
            m_tracks.move(curIdx, i);
            endMoveRows();
        } else {
            m_tracks[i] = nt;
            QModelIndex idx = createIndex(i, 0);
            emit dataChanged(idx, idx);
        }
    }

    emit countChanged();
}

void TrackModel::updateFiltered(const QList<Track> &newTracks) {
    QSet<QString> newPaths;
    for (const auto &t : newTracks) newPaths.insert(t.path);

    for (int i = m_tracks.size() - 1; i >= 0; --i) {
        if (!newPaths.contains(m_tracks[i].path)) {
            beginRemoveRows(QModelIndex(), i, i);
            m_tracks.removeAt(i);
            endRemoveRows();
        }
    }

    QSet<QString> curPaths;
    for (const auto &t : m_tracks) curPaths.insert(t.path);

    for (int i = 0; i < newTracks.size(); ++i) {
        const Track &nt = newTracks[i];
        if (!curPaths.contains(nt.path)) {
            beginInsertRows(QModelIndex(), i, i);
            m_tracks.insert(i, nt);
            endInsertRows();
            curPaths.insert(nt.path);
        } else {
            int curIdx = -1;
            for (int j = i; j < m_tracks.size(); ++j) {
                if (m_tracks[j].path == nt.path) { curIdx = j; break; }
            }
            if (curIdx > i) {
                beginMoveRows(QModelIndex(), curIdx, curIdx, QModelIndex(), i);
                m_tracks.move(curIdx, i);
                endMoveRows();
            }
        }
    }

    emit countChanged();
}

void TrackModel::moveRow(int from, int to) {
    if (from == to) return;
    if (from < 0 || from >= m_tracks.size()) return;
    if (to < 0 || to >= m_tracks.size()) return;

    const int dest = (to > from) ? to + 1 : to;
    beginMoveRows(QModelIndex(), from, from, QModelIndex(), dest);
    m_tracks.move(from, to);
    endMoveRows();
}

void TrackModel::updateTrack(int index, const Track &t) {
    if (index < 0 || index >= m_tracks.size()) return;
    m_tracks[index] = t;
    const QModelIndex idx = createIndex(index, 0);
    emit dataChanged(idx, idx);
}

bool TrackModel::removeByPath(const QString &path) {
    for (int i = 0; i < m_tracks.size(); ++i) {
        if (m_tracks[i].path == path) {
            beginRemoveRows(QModelIndex(), i, i);
            m_tracks.removeAt(i);
            endRemoveRows();
            emit countChanged();
            return true;
        }
    }
    return false;
}

void TrackModel::clear() {
    if (m_tracks.isEmpty()) return;
    beginResetModel();
    m_tracks.clear();
    endResetModel();
    emit countChanged();
}

const Track *TrackModel::at(int i) const {
    if (i < 0 || i >= m_tracks.size()) return nullptr;
    return &m_tracks[i];
}

Track *TrackModel::atMutable(int i) {
    if (i < 0 || i >= m_tracks.size()) return nullptr;
    return &m_tracks[i];
}