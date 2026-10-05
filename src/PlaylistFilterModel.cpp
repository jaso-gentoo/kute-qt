#include "PlaylistFilterModel.h"

PlaylistFilterModel::PlaylistFilterModel(QObject *parent)
    : QSortFilterProxyModel(parent) {
    setDynamicSortFilter(true);
    setFilterCaseSensitivity(Qt::CaseInsensitive);

    connect(this, &QAbstractItemModel::rowsInserted, this, [this]() { emit countChanged(); });
    connect(this, &QAbstractItemModel::rowsRemoved,  this, [this]() { emit countChanged(); });
    connect(this, &QAbstractItemModel::modelReset,   this, [this]() { emit countChanged(); });
    connect(this, &QAbstractItemModel::layoutChanged,this, [this]() { emit countChanged(); });
}