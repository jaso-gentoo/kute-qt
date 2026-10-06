#include "PlaylistModel.h"

PlaylistModel::PlaylistModel(QObject *parent) : QAbstractListModel(parent) {}

int PlaylistModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_playlists.size();
}

QVariant PlaylistModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_playlists.size()) return {};
    const Playlist &p = m_playlists[index.row()];
    switch (role) {
        case IdRole:         return p.id;
        case NameRole:       return p.name;
        case TrackCountRole: return p.tracks.size();
        case CoverRole:
            if (m_coverResolver) return m_coverResolver(p.id);
            return QString();
    }
    return {};
}

QHash<int, QByteArray> PlaylistModel::roleNames() const {
    return {
        { IdRole,         "playlistId" },
        { NameRole,       "playlistName" },
        { TrackCountRole, "playlistTrackCount" },
        { CoverRole,      "playlistCover" },
    };
}

void PlaylistModel::setPlaylists(const QList<Playlist> &list) {
    beginResetModel();
    m_playlists = list;
    endResetModel();
    emit countChanged();
}

void PlaylistModel::moveRow(int from, int to) {
    if (from == to) return;
    if (from < 0 || from >= m_playlists.size()) return;
    if (to < 0 || to >= m_playlists.size()) return;

    const int dest = (to > from) ? to + 1 : to;
    beginMoveRows(QModelIndex(), from, from, QModelIndex(), dest);
    m_playlists.move(from, to);
    endMoveRows();
}

void PlaylistModel::removeRow(int index) {
    if (index < 0 || index >= m_playlists.size()) return;
    beginRemoveRows(QModelIndex(), index, index);
    m_playlists.removeAt(index);
    endRemoveRows();
    emit countChanged();
}

void PlaylistModel::insertRow(const Playlist &p) {
    const int i = m_playlists.size();
    beginInsertRows(QModelIndex(), i, i);
    m_playlists.append(p);
    endInsertRows();
    emit countChanged();
}

void PlaylistModel::clear() {
    if (m_playlists.isEmpty()) return;
    beginResetModel();
    m_playlists.clear();
    endResetModel();
    emit countChanged();
}

void PlaylistModel::refreshCover(int index) {
    if (index < 0 || index >= m_playlists.size()) return;
    const QModelIndex idx = createIndex(index, 0);
    emit dataChanged(idx, idx, { CoverRole });
}