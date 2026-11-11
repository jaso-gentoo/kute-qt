#pragma once

#include <QSortFilterProxyModel>

class PlaylistFilterModel : public QSortFilterProxyModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit PlaylistFilterModel(QObject *parent = nullptr);

    int count() const { return rowCount(); }

signals:
    void countChanged();
};