#include "Library.h"
#include "LibraryInternal.h"

#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <QSet>
#include <QMap>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <algorithm>

void Library::loadOffsets() {
    m_lrcOffsets.clear();
    QFile f(offsetsPath());
    if (!f.open(QIODevice::ReadOnly)) return;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return;

    const QJsonObject o = doc.object();
    for (auto it = o.begin(); it != o.end(); ++it) {
        m_lrcOffsets.insert(it.key(), it.value().toDouble(0.25));
    }
}

void Library::saveOffsets() {
    QJsonObject o;
    for (auto it = m_lrcOffsets.begin(); it != m_lrcOffsets.end(); ++it) {
        o.insert(it.key(), it.value());
    }
    const QString path = offsetsPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    }
}

void Library::flushOffsetSave() {
    saveOffsets();
}

double Library::getLrcOffset(int index) const {
    if (index < 0 || index >= m_tracks.count()) return 0.25;
    const Track *t = m_tracks.at(index);
    if (!t) return 0.25;
    return m_lrcOffsets.value(t->path, 0.25);
}

void Library::setLrcOffset(int index, double value) {
    if (index < 0 || index >= m_tracks.count()) return;
    const Track *t = m_tracks.at(index);
    if (!t) return;
    if (qFuzzyCompare(m_lrcOffsets.value(t->path, 0.25) + 1.0, value + 1.0)) return;
    m_lrcOffsets.insert(t->path, value);
    m_offsetRevision++;
    emit offsetRevisionChanged();
    if (m_offsetSaveTimer) m_offsetSaveTimer->start();
}

void Library::loadLiked() {
    m_likedPaths.clear();
    QFile f(likedPath());
    if (!f.open(QIODevice::ReadOnly)) return;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return;

    const QJsonArray arr = doc.object().value("paths").toArray();
    for (const auto &v : arr) {
        const QString p = v.toString();
        if (!p.isEmpty()) m_likedPaths.insert(p);
    }
}

void Library::saveLiked() {
    QStringList sorted = m_likedPaths.values();
    sorted.sort(Qt::CaseInsensitive);

    QJsonArray arr;
    for (const QString &p : sorted) arr.append(p);

    QJsonObject o;
    o["paths"] = arr;
    o["version"] = 1;
    o["folder"] = m_folder;

    const QString path = likedPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    }
}

void Library::migrateLegacyLiked() {
    const QString legacy = kuteConfigDir() + "/liked.json";
    if (!QFile::exists(legacy)) return;
    if (m_folder.isEmpty()) return;

    const QString target = likedPath();
    if (target == legacy) return;
    if (QFile::exists(target)) return;

    QDir().mkpath(QFileInfo(target).absolutePath());
    QFile::rename(legacy, target);
}

void Library::flushLikedSave() {
    saveLiked();
}

bool Library::isLiked(int index) const {
    if (index < 0 || index >= m_tracks.count()) return false;
    const Track *t = m_tracks.at(index);
    if (!t) return false;
    return m_likedPaths.contains(t->path);
}

bool Library::isPathLiked(const QString &path) const {
    if (path.isEmpty()) return false;
    return m_likedPaths.contains(path);
}

bool Library::isCurrentLiked() const {
    if (m_currentTrack.path.isEmpty()) return false;
    return m_likedPaths.contains(m_currentTrack.path);
}

void Library::toggleLike(int index) {
    if (index < 0 || index >= m_tracks.count()) return;
    const Track *t = m_tracks.at(index);
    if (!t) return;

    const QString path = t->path;
    const bool wasLiked = m_likedPaths.contains(path);

    if (wasLiked) m_likedPaths.remove(path);
    else m_likedPaths.insert(path);

    m_likedRevision++;
    emit likedChanged();

    if (m_likedSaveTimer) m_likedSaveTimer->start();

    if (m_showOnlyLiked) {
        if (wasLiked) {
            m_tracks.removeByPath(path);
        } else {
            sortAndApply(true);
        }

        const QString currentPath = m_currentTrack.path;
        m_currentIndex = -1;
        if (!currentPath.isEmpty()) {
            for (int i = 0; i < m_tracks.count(); ++i) {
                const Track *tt = m_tracks.at(i);
                if (tt && tt->path == currentPath) { m_currentIndex = i; break; }
            }
        }
        emit currentChanged();
    }
}

void Library::toggleLikeByPath(const QString &path) {
    if (path.isEmpty()) return;

    const bool wasLiked = m_likedPaths.contains(path);

    if (wasLiked) m_likedPaths.remove(path);
    else m_likedPaths.insert(path);

    m_likedRevision++;
    emit likedChanged();

    if (m_likedSaveTimer) m_likedSaveTimer->start();

    if (m_showOnlyLiked) {
        if (wasLiked) {
            m_tracks.removeByPath(path);
        } else {
            sortAndApply(true);
        }

        const QString currentPath = m_currentTrack.path;
        m_currentIndex = -1;
        if (!currentPath.isEmpty()) {
            for (int i = 0; i < m_tracks.count(); ++i) {
                const Track *tt = m_tracks.at(i);
                if (tt && tt->path == currentPath) { m_currentIndex = i; break; }
            }
        }
        emit currentChanged();
    }
}

void Library::toggleCurrentLike() {
    if (m_currentTrack.path.isEmpty()) return;

    const QString path = m_currentTrack.path;
    const bool wasLiked = m_likedPaths.contains(path);

    if (wasLiked) m_likedPaths.remove(path);
    else m_likedPaths.insert(path);

    m_likedRevision++;
    emit likedChanged();

    if (m_likedSaveTimer) m_likedSaveTimer->start();

    if (m_showOnlyLiked) {
        if (wasLiked) {
            m_tracks.removeByPath(path);
        } else {
            sortAndApply(true);
        }

        m_currentIndex = -1;
        for (int i = 0; i < m_tracks.count(); ++i) {
            const Track *tt = m_tracks.at(i);
            if (tt && tt->path == path) { m_currentIndex = i; break; }
        }
        emit currentChanged();
    }
}

void Library::loadPlaylistOrder() {
    m_customOrder.clear();

    QFile f(playlistOrderPath());
    if (!f.open(QIODevice::ReadOnly)) return;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return;

    const QJsonObject o = doc.object();
    QJsonArray arr = o.value("customOrder").toArray();
    if (arr.isEmpty()) arr = o.value("order").toArray();
    if (arr.isEmpty()) arr = o.value("playlistOrder").toArray();

    for (const auto &v : arr) {
        const QString p = v.toString();
        if (!p.isEmpty()) m_customOrder.append(p);
    }
}

void Library::migrateLegacyPlaylistOrder() {
    const QString legacy = kuteConfigDir() + "/playlist_order.json";
    if (!QFile::exists(legacy)) return;
    if (m_folder.isEmpty()) return;

    const QString target = playlistOrderPath();
    if (target == legacy) return;
    if (QFile::exists(target)) return;

    QDir().mkpath(QFileInfo(target).absolutePath());
    QFile::rename(legacy, target);
}

void Library::savePlaylistOrderNow() {
    QJsonArray orderArr;
    for (const QString &p : m_customOrder) orderArr.append(p);

    QJsonObject o;
    o["version"] = 1;
    o["customOrder"] = orderArr;
    o["libraryPath"] = m_folder;
    o["lastModified"] = QDateTime::currentDateTime().toString(Qt::ISODate);

    const QString path = playlistOrderPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    }
}

void Library::savePlaylistOrder() {
    savePlaylistOrderNow();
}

void Library::sortAndApply(bool animate) {
    const QString currentPath = m_currentTrack.path;
    const QString q = m_filterText.toLower().trimmed();

    QList<Track> filtered;
    filtered.reserve(m_allTracks.size());

    for (const Track &t : m_allTracks) {
        if (m_showOnlyLiked && !m_likedPaths.contains(t.path)) continue;
        if (!m_filterArtist.isEmpty() && t.artist != m_filterArtist) continue;
        if (!m_filterAlbum.isEmpty() && t.album != m_filterAlbum) continue;
        if (!q.isEmpty()) {
            if (!t.title.toLower().contains(q) &&
                !t.artist.toLower().contains(q) &&
                !t.album.toLower().contains(q))
                continue;
        }
        filtered.append(t);
    }

    if (m_sortField == "custom") {
        QHash<QString, int> rank;
        rank.reserve(m_customOrder.size());
        for (int i = 0; i < m_customOrder.size(); ++i)
            rank.insert(m_customOrder[i], i);

        std::stable_sort(filtered.begin(), filtered.end(),
            [&rank](const Track &a, const Track &b) {
                const int ra = rank.value(a.path, 999999);
                const int rb = rank.value(b.path, 999999);
                if (ra != rb) return ra < rb;
                return QString::compare(a.path, b.path, Qt::CaseInsensitive) < 0;
            });
    } else {
        std::stable_sort(filtered.begin(), filtered.end(),
            [this](const Track &a, const Track &b) {
                int cmp = 0;
                if (m_sortField == "title") {
                    cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
                    if (cmp == 0) cmp = QString::compare(a.artist, b.artist, Qt::CaseInsensitive);
                } else if (m_sortField == "artist") {
                    cmp = QString::compare(a.artist, b.artist, Qt::CaseInsensitive);
                    if (cmp == 0) cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
                } else if (m_sortField == "album") {
                    cmp = QString::compare(a.album, b.album, Qt::CaseInsensitive);
                    if (cmp == 0) cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
                } else if (m_sortField == "duration") {
                    cmp = (a.durationMs < b.durationMs) ? -1 : (a.durationMs > b.durationMs) ? 1 : 0;
                } else {
                    cmp = QString::compare(a.path, b.path, Qt::CaseInsensitive);
                }
                return m_sortAscending ? (cmp < 0) : (cmp > 0);
            });
    }

    if (animate) m_tracks.setTracksAnimated(filtered);
    else          m_tracks.setTracks(filtered);

    m_currentIndex = -1;
    if (!currentPath.isEmpty()) {
        for (int i = 0; i < filtered.size(); ++i) {
            if (filtered[i].path == currentPath) { m_currentIndex = i; break; }
        }
    }
}

void Library::rebuildArtists() {
    QSet<QString> set;
    const QString q = m_filterText.toLower().trimmed();
    for (const Track &t : m_allTracks) {
        if (t.artist.isEmpty() || t.artist == "Unknown Artist") continue;
        if (!q.isEmpty() && !t.artist.toLower().contains(q)) continue;
        set.insert(t.artist);
    }
    QStringList list = set.values();
    list.sort(Qt::CaseInsensitive);
    if (!m_artistsAscending) std::reverse(list.begin(), list.end());
    m_artists = list;
    emit artistsChanged();
}

void Library::rebuildAlbums() {
    QMap<QString, QString> covers;
    QMap<QString, QString> thumbs;
    QSet<QString> names;
    const QString q = m_filterText.toLower().trimmed();
    for (const Track &t : m_allTracks) {
        if (t.album.isEmpty() || t.album == "Unknown Album") continue;
        if (!q.isEmpty() && !t.album.toLower().contains(q)) continue;
        names.insert(t.album);
        if (!covers.contains(t.album) && !t.cover.isEmpty())
            covers.insert(t.album, t.cover);
        if (!thumbs.contains(t.album) && !t.thumb.isEmpty())
            thumbs.insert(t.album, t.thumb);
    }
    QStringList sorted = names.values();
    sorted.sort(Qt::CaseInsensitive);
    if (!m_albumsAscending) std::reverse(sorted.begin(), sorted.end());

    m_albums.clear();
    m_albums.reserve(sorted.size());
    for (const QString &name : sorted) {
        QVariantMap m;
        m["name"]  = name;
        m["cover"] = covers.value(name, "");
        m["thumb"] = thumbs.value(name, "");
        m_albums.append(m);
    }
    emit albumsChanged();
}

void Library::setArtistsAscending(bool v) {
    if (m_artistsAscending == v) return;
    m_artistsAscending = v;
    m_settings->setValue("library/artistsAscending", v);
    emit artistsAscendingChanged();
    rebuildArtists();
}

void Library::setAlbumsAscending(bool v) {
    if (m_albumsAscending == v) return;
    m_albumsAscending = v;
    m_settings->setValue("library/albumsAscending", v);
    emit albumsAscendingChanged();
    rebuildAlbums();
}

void Library::rebuildSearch() {
    if (m_searchQuery.trimmed().isEmpty()) {
        m_searchResults.clear();
        return;
    }

    const QString q = m_searchQuery.toLower();
    QList<Track> results;
    results.reserve(m_allTracks.size());

    for (const Track &t : m_allTracks) {
        if (t.title.toLower().contains(q) ||
            t.artist.toLower().contains(q) ||
            t.album.toLower().contains(q)) {
            results.append(t);
        }
    }

    std::stable_sort(results.begin(), results.end(),
        [this](const Track &a, const Track &b) {
            int cmp = 0;
            if (m_sortField == "title") {
                cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
                if (cmp == 0) cmp = QString::compare(a.artist, b.artist, Qt::CaseInsensitive);
            } else if (m_sortField == "artist") {
                cmp = QString::compare(a.artist, b.artist, Qt::CaseInsensitive);
                if (cmp == 0) cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
            } else if (m_sortField == "album") {
                cmp = QString::compare(a.album, b.album, Qt::CaseInsensitive);
                if (cmp == 0) cmp = QString::compare(a.title, b.title, Qt::CaseInsensitive);
            } else if (m_sortField == "duration") {
                cmp = (a.durationMs < b.durationMs) ? -1 : (a.durationMs > b.durationMs) ? 1 : 0;
            } else {
                cmp = QString::compare(a.path, b.path, Qt::CaseInsensitive);
            }
            return m_sortAscending ? (cmp < 0) : (cmp > 0);
        });

    m_searchResults.updateFiltered(results);
}

void Library::applySort(const QString &field, bool ascending) {
    if (m_sortField == field && m_sortAscending == ascending) return;

    m_sortField = field;
    m_sortAscending = ascending;

    if (field == "custom") {
        if (m_customOrder.isEmpty()) {
            for (const Track &t : m_allTracks) m_customOrder.append(t.path);
            savePlaylistOrderNow();
        }
    }

    m_settings->setValue("library/sortField", field);
    m_settings->setValue("library/sortAscending", ascending);

    sortAndApply(false);
    rebuildSearch();
    emit sortChanged();
    emit currentChanged();
}

void Library::setFilterArtist(const QString &artist) {
    if (m_filterArtist == artist) return;
    m_filterArtist = artist;
    if (!artist.isEmpty() && !m_filterAlbum.isEmpty()) {
        m_filterAlbum.clear();
        emit filterAlbumChanged();
    }
    if (!artist.isEmpty() && m_showOnlyLiked) {
        m_showOnlyLiked = false;
        emit showOnlyLikedChanged();
    }
    sortAndApply(true);
    emit filterArtistChanged();
    emit currentChanged();
}

void Library::setFilterAlbum(const QString &album) {
    if (m_filterAlbum == album) return;
    m_filterAlbum = album;
    if (!album.isEmpty() && !m_filterArtist.isEmpty()) {
        m_filterArtist.clear();
        emit filterArtistChanged();
    }
    if (!album.isEmpty() && m_showOnlyLiked) {
        m_showOnlyLiked = false;
        emit showOnlyLikedChanged();
    }
    sortAndApply(true);
    emit filterAlbumChanged();
    emit currentChanged();
}

void Library::setFilterText(const QString &text) {
    if (m_filterText == text) return;
    m_filterText = text;
    rebuildArtists();
    rebuildAlbums();
    sortAndApply(false);

    if (m_playlistsProxy) {
        m_playlistsProxy->setFilterFixedString(text.trimmed());
    }

    if (!m_activePlaylistId.isEmpty()) {
        rebuildPlaylistTracks();
    }

    emit filterTextChanged();
    emit currentChanged();
}

void Library::clearFilter() {
    bool changed = false;
    if (!m_filterArtist.isEmpty()) {
        m_filterArtist.clear();
        emit filterArtistChanged();
        changed = true;
    }
    if (!m_filterAlbum.isEmpty()) {
        m_filterAlbum.clear();
        emit filterAlbumChanged();
        changed = true;
    }
    if (!m_filterText.isEmpty()) {
        m_filterText.clear();
        if (m_playlistsProxy) {
            m_playlistsProxy->setFilterFixedString(QString());
        }
        if (!m_activePlaylistId.isEmpty()) {
            rebuildPlaylistTracks();
        }
        emit filterTextChanged();
        changed = true;
    }
    if (changed) {
        rebuildArtists();
        rebuildAlbums();
        sortAndApply(true);
        emit currentChanged();
    }
}

void Library::setSearch(const QString &q) {
    if (m_searchQuery == q) return;
    m_searchQuery = q;
    rebuildSearch();
    emit searchQueryChanged();
}

void Library::toggleReorderMode() {
    if (!m_editMode) {
        if (m_showOnlyLiked) return;
        if (!m_filterText.isEmpty()) return;
        if (!m_filterArtist.isEmpty() || !m_filterAlbum.isEmpty()) return;

        if (m_sortField != "custom") {
            applySort("custom", true);
        }
        m_editMode = true;
    } else {
        m_editMode = false;
        savePlaylistOrderNow();
    }
    emit editModeChanged();
}

void Library::moveTrack(int from, int to) {
    if (from == to) return;
    if (from < 0 || to < 0) return;
    if (from >= m_tracks.count() || to >= m_tracks.count()) return;
    if (m_sortField != "custom") return;
    if (m_showOnlyLiked) return;
    if (!m_filterText.isEmpty()) return;
    if (!m_filterArtist.isEmpty() || !m_filterAlbum.isEmpty()) return;

    m_tracks.moveRow(from, to);

    if (m_currentIndex == from) {
        m_currentIndex = to;
    } else if (from < m_currentIndex && to >= m_currentIndex) {
        m_currentIndex--;
    } else if (from > m_currentIndex && to <= m_currentIndex) {
        m_currentIndex++;
    }
    emit currentChanged();

    QStringList order;
    for (int i = 0; i < m_tracks.count(); ++i) {
        const Track *t = m_tracks.at(i);
        if (t) order.append(t->path);
    }
    QSet<QString> seen;
    for (const QString &p : order) seen.insert(p);
    for (const Track &t : m_allTracks) {
        if (!seen.contains(t.path)) { order.append(t.path); seen.insert(t.path); }
    }
    m_customOrder = order;
    savePlaylistOrderNow();
}