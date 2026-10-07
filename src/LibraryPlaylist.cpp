#include "Library.h"
#include "LibraryInternal.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QStandardPaths>
#include <QUrl>
#include <QCryptographicHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

QString Library::playlistsPath() const {
    return playlistsPathFor(m_folder);
}

QString Library::playlistsPathFor(const QString &folder) const {
    if (folder.isEmpty()) {
        return kuteConfigDir() + "/playlists_orphan.json";
    }
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(folder.toUtf8(), QCryptographicHash::Sha1).toHex());
    return kuteConfigDir() + "/playlists/" + hash + ".json";
}

void Library::migrateLegacyPlaylists() {
    const QString legacy = kuteConfigDir() + "/playlists.json";
    if (!QFile::exists(legacy)) return;
    if (m_folder.isEmpty()) return;

    const QString target = playlistsPath();
    if (target == legacy) return;
    if (QFile::exists(target)) {
        return;
    }

    QDir().mkpath(QFileInfo(target).absolutePath());
    QFile::rename(legacy, target);
}

QString Library::playlistCoverThumbPath(const QString &id) const {
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
        + "/kute/playlist_covers/" + id + ".png";
}

void Library::refreshPlaylistModel() {
    m_playlistModel.setPlaylists(m_playlists);
}

void Library::loadPlaylists() {
    m_playlists.clear();
    QFile f(playlistsPath());
    if (!f.open(QIODevice::ReadOnly)) {
        refreshPlaylistModel();
        emit playlistsChanged();
        return;
    }

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        refreshPlaylistModel();
        emit playlistsChanged();
        return;
    }

    const QJsonArray arr = doc.object().value("playlists").toArray();
    for (const auto &v : arr) {
        const QJsonObject o = v.toObject();
        Playlist p;
        p.id    = o.value("id").toString();
        p.name  = o.value("name").toString();
        p.cover = o.value("cover").toString();
        const QJsonArray tracks = o.value("tracks").toArray();
        for (const auto &t : tracks) {
            const QString path = t.toString();
            if (!path.isEmpty()) p.tracks.append(path);
        }
        if (!p.id.isEmpty()) m_playlists.append(p);
    }
    refreshPlaylistModel();
    emit playlistsChanged();
}

void Library::savePlaylists() {
    QJsonArray arr;
    for (const Playlist &p : m_playlists) {
        QJsonObject o;
        o["id"]   = p.id;
        o["name"] = p.name;
        if (!p.cover.isEmpty()) o["cover"] = p.cover;
        QJsonArray tracks;
        for (const QString &t : p.tracks) tracks.append(t);
        o["tracks"] = tracks;
        arr.append(o);
    }

    QJsonObject root;
    root["version"]   = 1;
    root["playlists"] = arr;
    root["folder"]    = m_folder;

    const QString path = playlistsPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    }
}

const Playlist *Library::findPlaylist(const QString &id) const {
    for (const Playlist &p : m_playlists) {
        if (p.id == id) return &p;
    }
    return nullptr;
}

Playlist *Library::findPlaylistMutable(const QString &id) {
    for (Playlist &p : m_playlists) {
        if (p.id == id) return &p;
    }
    return nullptr;
}

QString Library::playlistCover(const QString &id) const {
    const Playlist *p = findPlaylist(id);
    if (!p) return {};
    if (p->cover.isEmpty()) return {};
    const QString thumb = playlistCoverThumbPath(id);
    if (!QFile::exists(thumb)) return {};
    const QFileInfo fi(thumb);
    return QUrl::fromLocalFile(thumb).toString()
        + "?t=" + QString::number(fi.lastModified().toMSecsSinceEpoch());
}

int Library::playlistIndexOf(const QString &playlistId, const QString &trackPath) const {
    const Playlist *p = findPlaylist(playlistId);
    if (!p) return -1;
    return p->tracks.indexOf(trackPath);
}

bool Library::isPathInPlaylist(const QString &playlistId, const QString &path) const {
    const Playlist *p = findPlaylist(playlistId);
    if (!p) return false;
    return p->tracks.contains(path);
}

QString Library::createPlaylistWithTrack(const QString &name, const QString &trackPath) {
    Playlist p;
    p.id   = QUuid::createUuid().toString(QUuid::WithoutBraces);
    p.name = name.trimmed().isEmpty() ? QStringLiteral("New Playlist") : name.trimmed();
    if (!trackPath.isEmpty()) p.tracks.append(trackPath);

    m_playlists.append(p);
    savePlaylists();
    m_playlistModel.insertRow(p);
    emit playlistsChanged();

    if (m_activePlaylistId == p.id) rebuildPlaylistTracks();
    return p.id;
}

void Library::deletePlaylist(const QString &id) {
    for (int i = 0; i < m_playlists.size(); ++i) {
        if (m_playlists[i].id == id) {
            QFile::remove(playlistCoverThumbPath(id));
            m_playlists.removeAt(i);
            savePlaylists();
            m_playlistModel.removeRow(i);
            emit playlistsChanged();
            m_coverVersion++;
            emit coverVersionChanged();

            if (m_activePlaylistId == id) {
                m_activePlaylistId.clear();
                m_playlistTracks.clear();
                emit activePlaylistChanged();
            }
            if (m_playbackPlaylistId == id) {
                m_playbackPlaylistId.clear();
            }
            return;
        }
    }
}

void Library::renamePlaylist(const QString &id, const QString &name) {
    Playlist *p = findPlaylistMutable(id);
    if (!p) return;
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || p->name == trimmed) return;
    p->name = trimmed;
    savePlaylists();
    refreshPlaylistModel();
    emit playlistsChanged();
    if (m_activePlaylistId == id) emit activePlaylistChanged();
}

void Library::setPlaylistCover(const QString &id, const QString &coverPath) {
    Playlist *p = findPlaylistMutable(id);
    if (!p) return;

    QString normalized = coverPath;
    if (normalized.startsWith("file://")) {
        normalized = QUrl(normalized).toLocalFile();
    }
    if (normalized.isEmpty() || !QFile::exists(normalized)) return;

    QImage src(normalized);
    if (src.isNull()) return;

    const QString outPath = playlistCoverThumbPath(id);
    QDir().mkpath(QFileInfo(outPath).absolutePath());

    const int sz = 256;
    QImage t = src.scaled(sz, sz, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
    const int x = (t.width() - sz) / 2;
    const int y = (t.height() - sz) / 2;
    t = t.copy(x, y, sz, sz);

    QImage rounded(sz, sz, QImage::Format_ARGB32);
    rounded.fill(Qt::transparent);

    QPainter pp(&rounded);
    pp.setRenderHint(QPainter::Antialiasing, true);
    pp.setRenderHint(QPainter::SmoothPixmapTransform, true);
    QPainterPath path;
    path.addRoundedRect(0, 0, sz, sz, 44, 44);
    pp.setClipPath(path);
    pp.drawImage(0, 0, t);
    pp.end();

    if (QFile::exists(outPath)) QFile::remove(outPath);
    if (!rounded.save(outPath, "PNG")) return;

    p->cover = normalized;
    savePlaylists();

    for (int i = 0; i < m_playlists.size(); ++i) {
        if (m_playlists[i].id == id) {
            m_playlistModel.refreshCover(i);
            break;
        }
    }

    emit playlistsChanged();
    if (m_activePlaylistId == id) emit activePlaylistChanged();
    m_coverVersion++;
    emit coverVersionChanged();
}

void Library::clearPlaylistCover(const QString &id) {
    Playlist *p = findPlaylistMutable(id);
    if (!p) return;
    if (p->cover.isEmpty()) return;
    p->cover.clear();
    QFile::remove(playlistCoverThumbPath(id));
    savePlaylists();

    for (int i = 0; i < m_playlists.size(); ++i) {
        if (m_playlists[i].id == id) {
            m_playlistModel.refreshCover(i);
            break;
        }
    }

    emit playlistsChanged();
    if (m_activePlaylistId == id) emit activePlaylistChanged();
    m_coverVersion++;
    emit coverVersionChanged();
}

bool Library::savePlaylistCoverTo(const QString &id, const QString &destPath) {
    const Playlist *p = findPlaylist(id);
    if (!p || p->cover.isEmpty()) return false;
    QString local = destPath;
    if (local.startsWith("file://")) {
        local = QUrl(local).toLocalFile();
    }
    if (local.isEmpty()) return false;
    if (QFile::exists(local)) QFile::remove(local);
    return QFile::copy(p->cover, local);
}

void Library::addTrackToPlaylist(const QString &playlistId, const QString &trackPath) {
    if (trackPath.isEmpty()) return;
    Playlist *p = findPlaylistMutable(playlistId);
    if (!p) return;
    if (p->tracks.contains(trackPath)) return;
    p->tracks.append(trackPath);
    savePlaylists();
    refreshPlaylistModel();
    emit playlistsChanged();
    if (m_activePlaylistId == playlistId) {
        rebuildPlaylistTracks(true);
        emit activePlaylistChanged();
    }
}

void Library::removeTrackFromPlaylist(const QString &playlistId, int index) {
    Playlist *p = findPlaylistMutable(playlistId);
    if (!p) return;
    if (index < 0 || index >= p->tracks.size()) return;
    p->tracks.removeAt(index);
    savePlaylists();
    refreshPlaylistModel();
    emit playlistsChanged();
    if (m_activePlaylistId == playlistId) {
        rebuildPlaylistTracks(true);
        emit activePlaylistChanged();
    }
}

void Library::moveTrackInPlaylist(const QString &playlistId, int from, int to) {
    Playlist *p = findPlaylistMutable(playlistId);
    if (!p) return;
    if (from == to) return;
    if (from < 0 || to < 0) return;
    if (from >= p->tracks.size() || to >= p->tracks.size()) return;
    p->tracks.move(from, to);
    savePlaylists();

    if (m_activePlaylistId == playlistId) {
        m_playlistTracks.moveRow(from, to);
    }
    emit playlistsChanged();
}

void Library::movePlaylist(int from, int to) {
    if (from == to) return;
    if (from < 0 || to < 0) return;
    if (from >= m_playlists.size() || to >= m_playlists.size()) return;
    m_playlists.move(from, to);
    savePlaylists();
    m_playlistModel.moveRow(from, to);
    emit playlistsChanged();
}

void Library::setActivePlaylist(const QString &id) {
    if (m_activePlaylistId == id) return;
    m_activePlaylistId = id;
    if (id.isEmpty()) {
        m_playbackPlaylistId.clear();
    }
    rebuildPlaylistTracks();
    emit activePlaylistChanged();
}

int Library::activePlaylistTrackCount() const {
    const Playlist *p = findPlaylist(m_activePlaylistId);
    return p ? p->tracks.size() : 0;
}

void Library::setPlaybackContext(const QString &ctx) {
    if (ctx == QLatin1String("library")) {
        m_playbackPlaylistId.clear();
    } else if (ctx == QLatin1String("playlist")) {
        if (!m_activePlaylistId.isEmpty()) {
            m_playbackPlaylistId = m_activePlaylistId;
        }
    }
}

void Library::rebuildPlaylistTracks(bool incremental) {
    QList<Track> list;
    if (!m_activePlaylistId.isEmpty()) {
        const Playlist *p = findPlaylist(m_activePlaylistId);
        if (p) {
            QHash<QString, const Track*> byPath;
            byPath.reserve(m_allTracks.size());
            for (const Track &t : m_allTracks) byPath.insert(t.path, &t);

            const QString q = m_filterText.toLower().trimmed();

            list.reserve(p->tracks.size());
            for (const QString &path : p->tracks) {
                if (const Track *t = byPath.value(path, nullptr)) {
                    if (!q.isEmpty()) {
                        if (!t->title.toLower().contains(q) &&
                            !t->artist.toLower().contains(q) &&
                            !t->album.toLower().contains(q))
                            continue;
                    }
                    list.append(*t);
                }
            }
        }
    }
    if (incremental) m_playlistTracks.updateFiltered(list);
    else             m_playlistTracks.setTracks(list);
}

TrackModel *Library::currentPlaybackModel() {
    return m_playbackPlaylistId.isEmpty() ? &m_tracks : &m_playlistTracks;
}

void Library::playFromModel(TrackModel *model, int index) {
    if (!model) return;
    if (index < 0 || index >= model->count()) return;
    const Track *t = model->at(index);
    if (!t) return;
    m_currentIndex = index;
    startTrack(*t);
}

void Library::playPlaylistIndex(int index) {
    if (m_activePlaylistId.isEmpty()) return;
    m_playbackPlaylistId = m_activePlaylistId;
    playFromModel(&m_playlistTracks, index);
}