#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <functional>
#include "TrackModel.h"

class PlaylistModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        TrackCountRole,
        CoverRole,
    };

    explicit PlaylistModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setPlaylists(const QList<Playlist> &list);
    void moveRow(int from, int to);
    void removeRow(int index);
    void insertRow(const Playlist &p);
    void clear();
    int count() const { return m_playlists.size(); }

    void setCoverResolver(std::function<QString(const QString&)> r) { m_coverResolver = r; }
    void refreshCover(int index);

signals:
    void countChanged();

private:
    QList<Playlist> m_playlists;
    std::function<QString(const QString&)> m_coverResolver;
};