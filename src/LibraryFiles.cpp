#include "Library.h"
#include "LibraryInternal.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QFile>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QCryptographicHash>
#include <QUrl>
#include <QThread>

#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/audioproperties.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>
#include <taglib/unsynchronizedlyricsframe.h>
#include <taglib/textidentificationframe.h>
#include <taglib/xiphcomment.h>

void Library::extractImages(const QString &filePath,
                            QString &coverOut,
                            QString &thumbOut) const {
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5).toHex());

    const QString coverPath = coverCacheDir() + "/" + hash + ".jpg";
    const QString thumbPath = thumbCacheDir() + "/" + hash + ".png";

    if (QFile::exists(coverPath) && QFile::exists(thumbPath)) {
        coverOut = coverPath;
        thumbOut = thumbPath;
        return;
    }

    QByteArray data;
    {
        StderrSilencer silencer;
        TagLib::FileRef f = makeFileRef(filePath);
        if (f.isNull() || !f.file()) return;

        TagLib::File *file = f.file();

        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
            if (auto *tag = mpeg->ID3v2Tag()) {
                const auto list = tag->frameList("APIC");
                if (!list.isEmpty()) {
                    if (auto *pic = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(list.front())) {
                        data = QByteArray(pic->picture().data(), pic->picture().size());
                    }
                }
            }
        } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
            const auto pics = flac->pictureList();
            if (!pics.isEmpty()) {
                const auto *pic = pics.front();
                data = QByteArray(pic->data().data(), pic->data().size());
            }
        }
    }

    if (data.isEmpty()) return;

    QImage src;
    if (!src.loadFromData(data)) return;

    if (!QFile::exists(coverPath)) {
        QImage cover = (src.width() > 500 || src.height() > 500)
            ? src.scaled(500, 500, Qt::KeepAspectRatio, Qt::SmoothTransformation)
            : src;
        if (cover.save(coverPath, "JPEG", 88)) coverOut = coverPath;
    } else {
        coverOut = coverPath;
    }

    if (!QFile::exists(thumbPath)) {
        const int sz = 256;
        QImage t = src.scaled(sz, sz, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
        const int x = (t.width() - sz) / 2;
        const int y = (t.height() - sz) / 2;
        t = t.copy(x, y, sz, sz);

        QImage rounded(sz, sz, QImage::Format_ARGB32);
        rounded.fill(Qt::transparent);

        QPainter p(&rounded);
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setRenderHint(QPainter::SmoothPixmapTransform, true);
        QPainterPath path;
        path.addRoundedRect(0, 0, sz, sz, 44, 44);
        p.setClipPath(path);
        p.drawImage(0, 0, t);
        p.end();

        if (rounded.save(thumbPath, "PNG")) thumbOut = thumbPath;
    } else {
        thumbOut = thumbPath;
    }
}


QString Library::metaCachePath() const {
    return kuteConfigDir() + "/meta_cache.json";
}

void Library::loadMetaCache() {
    m_metaCache.clear();
    QFile f(metaCachePath());
    if (!f.open(QIODevice::ReadOnly)) return;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return;

    const QJsonObject files = doc.object().value("files").toObject();
    for (auto it = files.begin(); it != files.end(); ++it) {
        const QJsonObject o = it.value().toObject();
        CachedMeta c;
        c.mtime      = qint64(o.value("mtime").toDouble());
        c.size       = qint64(o.value("size").toDouble());
        c.title      = o.value("title").toString();
        c.artist     = o.value("artist").toString();
        c.album      = o.value("album").toString();
        c.durationMs = qint64(o.value("durationMs").toDouble());
        c.bitrate    = o.value("bitrate").toInt();
        c.sampleRate = o.value("sampleRate").toInt();
        c.channels   = o.value("channels").toInt();
        c.year       = o.value("year").toInt();
        m_metaCache.insert(it.key(), c);
    }
}

void Library::saveMetaCache() {
    if (!m_metaCacheDirty) return;
    m_metaCacheDirty = false;
    QJsonObject files;
    for (auto it = m_metaCache.begin(); it != m_metaCache.end(); ++it) {
        QJsonObject o;
        o["mtime"]      = double(it->mtime);
        o["size"]       = double(it->size);
        o["title"]      = it->title;
        o["artist"]     = it->artist;
        o["album"]      = it->album;
        o["durationMs"] = double(it->durationMs);
        o["bitrate"]    = it->bitrate;
        o["sampleRate"] = it->sampleRate;
        o["channels"]   = it->channels;
        o["year"]       = it->year;
        files[it.key()] = o;
    }
    QJsonObject root;
    root["version"] = 1;
    root["files"]   = files;

    QDir().mkpath(QFileInfo(metaCachePath()).absolutePath());
    QFile f(metaCachePath());
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
    }
}

void Library::scheduleMetaCacheSave() {
    if (m_metaSaveTimer) m_metaSaveTimer->start();
}

void Library::updateFolderWatcher() {
    if (!m_folderWatcher) return;

    const QStringList oldDirs = m_folderWatcher->directories();
    if (!oldDirs.isEmpty()) m_folderWatcher->removePaths(oldDirs);

    if (m_folder.isEmpty() || !QDir(m_folder).exists()) return;

    QStringList dirs;
    dirs.append(m_folder);
    QDirIterator dit(m_folder, QDir::Dirs | QDir::NoDotAndDotDot,
                     QDirIterator::Subdirectories);
    while (dit.hasNext()) dirs.append(dit.next());

    if (!dirs.isEmpty()) m_folderWatcher->addPaths(dirs);
}

Track Library::loadOrParseTrack(const QString &path) {
    Track t;
    t.path = path;

    const QFileInfo info(path);
    t.fileSize = info.size();
    t.format   = info.suffix().toUpper();
    const qint64 mtime = info.lastModified().toMSecsSinceEpoch();

    auto it = m_metaCache.find(path);
    if (it != m_metaCache.end() && it->mtime == mtime && it->size == t.fileSize) {
        const CachedMeta &c = it.value();
        t.title      = c.title;
        t.artist     = c.artist;
        t.album      = c.album;
        t.durationMs = c.durationMs;
        t.bitrate    = c.bitrate;
        t.sampleRate = c.sampleRate;
        t.channels   = c.channels;
        t.year       = c.year;
        extractImages(path, t.cover, t.thumb);
        return t;
    }

    {
        StderrSilencer silencer;
        TagLib::FileRef f = makeFileRef(path);
        if (!f.isNull() && f.tag()) {
            TagLib::Tag *tag = f.tag();
            const QString tagTitle  = QString::fromUtf8(tag->title().to8Bit(true).c_str());
            const QString tagArtist = QString::fromUtf8(tag->artist().to8Bit(true).c_str());
            const QString tagAlbum  = QString::fromUtf8(tag->album().to8Bit(true).c_str());
            t.title  = tagTitle.isEmpty()  ? info.completeBaseName() : tagTitle.trimmed();
            t.artist = tagArtist.isEmpty() ? QStringLiteral("Unknown Artist") : tagArtist.trimmed();
            t.album  = tagAlbum.isEmpty()  ? QStringLiteral("Unknown Album")  : tagAlbum.trimmed();
            t.year   = tag->year();
            if (f.audioProperties()) {
                t.durationMs = f.audioProperties()->lengthInMilliseconds();
                t.bitrate    = f.audioProperties()->bitrate();
                t.sampleRate = f.audioProperties()->sampleRate();
                t.channels   = f.audioProperties()->channels();
            }
        } else {
            t.title  = info.completeBaseName();
            t.artist = QStringLiteral("Unknown Artist");
            t.album  = QStringLiteral("Unknown Album");
        }
    }

    CachedMeta c;
    c.mtime      = mtime;
    c.size       = t.fileSize;
    c.title      = t.title;
    c.artist     = t.artist;
    c.album      = t.album;
    c.durationMs = t.durationMs;
    c.bitrate    = t.bitrate;
    c.sampleRate = t.sampleRate;
    c.channels   = t.channels;
    c.year       = t.year;
    m_metaCache.insert(path, c);
    m_metaCacheDirty = true;
    scheduleMetaCacheSave();

    extractImages(path, t.cover, t.thumb);
    return t;
}

void Library::loadFolder(const QString &path) {
    QString localPath = path;
    if (localPath.startsWith("file://")) localPath = QUrl(localPath).toLocalFile();
    if (localPath.isEmpty() || !QDir(localPath).exists()) return;

    const QStringList filters = {
        "*.mp3", "*.flac", "*.ogg", "*.opus",
        "*.wav", "*.m4a", "*.aac"
    };

    m_allTracks.clear();
    QDirIterator it(localPath, filters, QDir::Files, QDirIterator::Subdirectories);

    while (it.hasNext()) {
        const QString filePath = it.next();
        m_allTracks.append(loadOrParseTrack(filePath));
    }

    m_player->stop();
    m_pendingPlay = false;
    m_playRetries = 0;
    m_folder = localPath;
    m_currentIndex = -1;
    m_currentTrack = Track();
    m_intentPlaying = false;
    m_filterArtist.clear();
    m_filterAlbum.clear();
    m_filterText.clear();
    m_searchQuery.clear();
    m_editMode = false;
    m_showOnlyLiked = false;

    const bool hadActivePlaylist = !m_activePlaylistId.isEmpty();
    m_playlists.clear();
    m_activePlaylistId.clear();
    m_playbackPlaylistId.clear();
    m_playlistTracks.clear();
    if (m_playlistsProxy) m_playlistsProxy->setFilterFixedString(QString());

    migrateLegacyPlaylists();
    migrateLegacyPlaylistOrder();
    migrateLegacyLiked();

    m_likedPaths.clear();
    loadLiked();
    m_likedRevision++;
    emit likedChanged();

    m_customOrder.clear();
    loadPlaylistOrder();

    loadPlaylists();

    rebuildArtists();
    rebuildAlbums();
    sortAndApply(false);
    m_searchResults.clear();

    if (hadActivePlaylist) emit activePlaylistChanged();

    m_settings->setValue("library/folder", localPath);

    updateFolderWatcher();

    emit folderChanged();
    emit trackCountChanged();
    emit currentChanged();
    emit filterArtistChanged();
    emit filterAlbumChanged();
    emit filterTextChanged();
    emit searchQueryChanged();
    emit editModeChanged();
    emit showOnlyLikedChanged();
    schedulePresence();
}

void Library::applyFileRename(const QString &oldPath, const QString &newPath) {
    bool customChanged = false;
    for (QString &p : m_customOrder) {
        if (p == oldPath) { p = newPath; customChanged = true; }
    }
    if (customChanged) savePlaylistOrderNow();

    bool playlistsDirty = false;
    for (Playlist &pl : m_playlists) {
        for (QString &t : pl.tracks) {
            if (t == oldPath) { t = newPath; playlistsDirty = true; }
        }
    }
    if (playlistsDirty) {
        savePlaylists();
        refreshPlaylistModel();
        emit playlistsChanged();
    }

    if (m_likedPaths.contains(oldPath)) {
        m_likedPaths.remove(oldPath);
        m_likedPaths.insert(newPath);
        m_likedRevision++;
        emit likedChanged();
        if (m_likedSaveTimer) m_likedSaveTimer->start();
    }

    auto metaIt = m_metaCache.find(oldPath);
    if (metaIt != m_metaCache.end()) {
        CachedMeta c = metaIt.value();
        m_metaCache.erase(metaIt);
        m_metaCache.insert(newPath, c);
        m_metaCacheDirty = true;
        scheduleMetaCacheSave();
    }

    auto offsetIt = m_lrcOffsets.find(oldPath);
    if (offsetIt != m_lrcOffsets.end()) {
        const double off = offsetIt.value();
        m_lrcOffsets.remove(oldPath);
        m_lrcOffsets.insert(newPath, off);
        m_offsetRevision++;
        emit offsetRevisionChanged();
        if (m_offsetSaveTimer) m_offsetSaveTimer->start();
    }

    const QString oldHash = QString::fromLatin1(
        QCryptographicHash::hash(oldPath.toUtf8(), QCryptographicHash::Md5).toHex());
    QFile::remove(coverCacheDir() + "/" + oldHash + ".jpg");
    QFile::remove(thumbCacheDir() + "/" + oldHash + ".png");

    for (Track &t : m_allTracks) {
        if (t.path == oldPath) {
            t.path = newPath;
            t.cover.clear();
            t.thumb.clear();
            extractImages(newPath, t.cover, t.thumb);
            break;
        }
    }

    if (m_currentTrack.path == oldPath) {
        m_currentTrack.path = newPath;
        m_currentTrack.cover.clear();
        m_currentTrack.thumb.clear();
        extractImages(newPath, m_currentTrack.cover, m_currentTrack.thumb);
    }

    if (!m_activePlaylistId.isEmpty()) rebuildPlaylistTracks();

    m_coverVersion++;
    emit coverVersionChanged();
    emit currentChanged();
}

bool Library::saveMetadata(int index,
                           const QString &title,
                           const QString &artist,
                           const QString &album,
                           const QString &coverSourcePath,
                           const QString &newFileName) {
    if (index < 0 || index >= m_tracks.count()) return false;
    const Track *old = m_tracks.at(index);
    if (!old) return false;

    QString path = old->path;
    const bool wasCurrent = (index == m_currentIndex);
    const bool wasPlaying = isPlaying();
    const qint64 savedPos = wasCurrent ? m_player->position() : 0;

    const QString finalAlbum = album.isEmpty() ? QStringLiteral("Unknown Album") : album;

    const QString trimmedName = newFileName.trimmed();
    if (!trimmedName.isEmpty()) {
        const QString oldBase = QFileInfo(path).fileName();
        if (trimmedName != oldBase) {
            if (trimmedName.contains(QChar(0x2F)) || trimmedName.contains(QChar(0x5C)) || trimmedName.contains(QChar(0x3A))) {
                qWarning() << "saveMetadata: invalid chars in new filename";
                return false;
            }
            QString newName = trimmedName;
            if (!newName.contains(QChar(0x2E))) {
                const QString suffix = QFileInfo(path).suffix();
                if (!suffix.isEmpty()) newName += "." + suffix;
            }
            const QString newPath = QFileInfo(path).absolutePath() + "/" + newName;

            if (QFile::exists(newPath)) {
                qWarning() << "saveMetadata: rename target exists" << newPath;
                return false;
            }

            if (wasCurrent) {
                m_player->stop();
#ifdef Q_OS_WIN
                m_player->setSource(QUrl());
                waitForFileRelease(path, 2000);
#endif
                m_intentPlaying = false;
                m_pendingPlay = false;
            }

            if (!QFile::rename(path, newPath)) {
                qWarning() << "saveMetadata: rename failed" << path << "->" << newPath;
                if (wasCurrent) restorePlayer(path, savedPos, wasPlaying);
                return false;
            }

            applyFileRename(path, newPath);
            path = newPath;

            Track copy = *old;
            copy.path = path;
            m_tracks.updateTrack(index, copy);
        }
    }

    if (wasCurrent) {
        m_player->stop();
#ifdef Q_OS_WIN
        m_player->setSource(QUrl());
        waitForFileRelease(path, 2000);
#endif
        m_intentPlaying = false;
        m_pendingPlay = false;
    }

    const QString normalizedCover = normalizeLocalPath(coverSourcePath);
    const bool wantCover = !normalizedCover.isEmpty();

    bool ok = false;
    {
        StderrSilencer silencer;

        TagLib::FileRef fr = makeFileRef(path);
        if (fr.isNull() || !fr.file()) {
            qWarning() << "saveMetadata: cannot open file" << path;
            if (wasCurrent) restorePlayer(path, savedPos, wasPlaying);
            return false;
        }

        TagLib::File *file = fr.file();

        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
            TagLib::ID3v2::Tag *tag = mpeg->ID3v2Tag(true);
            if (!title.isEmpty()) tag->setTitle(toTaglib(title));
            if (!artist.isEmpty()) tag->setArtist(toTaglib(artist));
            tag->setAlbum(toTaglib(finalAlbum));

            if (wantCover) {
                QFile img(normalizedCover);
                if (img.open(QIODevice::ReadOnly)) {
                    const QByteArray data = img.readAll();
                    QString mime = "image/jpeg";
                    if (normalizedCover.endsWith(".png", Qt::CaseInsensitive)) mime = "image/png";
                    else if (normalizedCover.endsWith(".webp", Qt::CaseInsensitive)) mime = "image/webp";

                    tag->removeFrames("APIC");
                    auto *frame = new TagLib::ID3v2::AttachedPictureFrame;
                    frame->setMimeType(mime.toStdString());
                    frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
                    frame->setPicture(TagLib::ByteVector(data.constData(), data.size()));
                    tag->addFrame(frame);
                }
            }

            ok = mpeg->save();
        } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
            if (flac->tag()) {
                if (!title.isEmpty()) flac->tag()->setTitle(toTaglib(title));
                if (!artist.isEmpty()) flac->tag()->setArtist(toTaglib(artist));
                flac->tag()->setAlbum(toTaglib(finalAlbum));
            }

            if (wantCover) {
                QFile img(normalizedCover);
                if (img.open(QIODevice::ReadOnly)) {
                    const QByteArray data = img.readAll();
                    QString mime = "image/jpeg";
                    if (normalizedCover.endsWith(".png", Qt::CaseInsensitive)) mime = "image/png";

                    flac->removePictures();
                    auto *pic = new TagLib::FLAC::Picture;
                    pic->setMimeType(mime.toStdString());
                    pic->setType(TagLib::FLAC::Picture::FrontCover);
                    pic->setData(TagLib::ByteVector(data.constData(), data.size()));
                    flac->addPicture(pic);
                }
            }

            ok = flac->save();
        } else {
            TagLib::Tag *tag = file->tag();
            if (!tag) {
                if (wasCurrent) restorePlayer(path, savedPos, wasPlaying);
                return false;
            }
            if (!title.isEmpty()) tag->setTitle(toTaglib(title));
            if (!artist.isEmpty()) tag->setArtist(toTaglib(artist));
            tag->setAlbum(toTaglib(finalAlbum));
            ok = file->save();
        }
    }

    if (!ok) {
        qWarning() << "saveMetadata: TagLib save() failed for" << path;
        if (wasCurrent) restorePlayer(path, savedPos, wasPlaying);
        return false;
    }

    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(path.toUtf8(), QCryptographicHash::Md5).toHex());
    if (wantCover) {
        QFile::remove(coverCacheDir() + "/" + hash + ".jpg");
        QFile::remove(thumbCacheDir() + "/" + hash + ".png");
    }

    Track updated = *old;
    if (!title.isEmpty()) updated.title = title;
    if (!artist.isEmpty()) updated.artist = artist;
    updated.album = finalAlbum;

    QString newCover, newThumb;
    extractImages(path, newCover, newThumb);
    updated.cover = newCover;
    updated.thumb = newThumb;

    {
        const QFileInfo fi(path);
        CachedMeta c;
        c.mtime      = fi.lastModified().toMSecsSinceEpoch();
        c.size       = fi.size();
        c.title      = updated.title;
        c.artist     = updated.artist;
        c.album      = updated.album;
        c.durationMs = updated.durationMs;
        c.bitrate    = updated.bitrate;
        c.sampleRate = updated.sampleRate;
        c.channels   = updated.channels;
        c.year       = updated.year;
        m_metaCache.insert(path, c);
        scheduleMetaCacheSave();
    }

    for (auto &t : m_allTracks) {
        if (t.path == path) { t = updated; break; }
    }

    m_tracks.updateTrack(index, updated);
    if (wasCurrent) m_currentTrack = updated;

    if (!m_activePlaylistId.isEmpty()) rebuildPlaylistTracks();

    if (wasCurrent) restorePlayer(path, savedPos, wasPlaying);

    rebuildArtists();
    rebuildAlbums();
    emit currentChanged();

    if (wantCover) {
        m_coverVersion++;
        emit coverVersionChanged();
    }
    return true;
}

bool Library::removeCurrentCover() {
    if (m_currentTrack.path.isEmpty()) return false;
    const QString path = m_currentTrack.path;

    const bool wasPlaying = isPlaying();
    const qint64 savedPos = m_player->position();
    m_player->stop();
#ifdef Q_OS_WIN
    m_player->setSource(QUrl());
    waitForFileRelease(path, 2000);
#endif
    m_intentPlaying = false;
    m_pendingPlay = false;

    bool ok = false;
    {
        StderrSilencer silencer;
        TagLib::FileRef fr = makeFileRef(path);
        if (!fr.isNull() && fr.file()) {
            TagLib::File *file = fr.file();

            if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
                if (auto *tag = mpeg->ID3v2Tag()) {
                    tag->removeFrames("APIC");
                    ok = mpeg->save();
                }
            } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
                flac->removePictures();
                ok = flac->save();
            }
        }
    }

    if (!ok) {
        qWarning() << "removeCurrentCover: failed for" << path;
        restorePlayer(path, savedPos, wasPlaying);
        return false;
    }

    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(path.toUtf8(), QCryptographicHash::Md5).toHex());
    QFile::remove(coverCacheDir() + "/" + hash + ".jpg");
    QFile::remove(thumbCacheDir() + "/" + hash + ".png");

    for (auto &t : m_allTracks) {
        if (t.path == path) {
            t.cover.clear();
            t.thumb.clear();
            break;
        }
    }

    for (int i = 0; i < m_tracks.count(); ++i) {
        const Track *tt = m_tracks.at(i);
        if (tt && tt->path == path) {
            Track copy = *tt;
            copy.cover.clear();
            copy.thumb.clear();
            m_tracks.updateTrack(i, copy);
            break;
        }
    }

    m_currentTrack.cover.clear();
    m_currentTrack.thumb.clear();

    if (!m_activePlaylistId.isEmpty()) rebuildPlaylistTracks();

    m_coverVersion++;
    emit coverVersionChanged();
    emit currentChanged();

    restorePlayer(path, savedPos, wasPlaying);
    return true;
}

bool Library::saveCoverTo(const QString &destPath) {
    if (m_currentTrack.path.isEmpty()) return false;

    QString local = normalizeLocalPath(destPath);
    if (local.isEmpty()) return false;

    const bool wasPlaying = isPlaying();
    const qint64 savedPos = m_player->position();
    m_player->stop();
#ifdef Q_OS_WIN
    m_player->setSource(QUrl());
    waitForFileRelease(m_currentTrack.path, 2000);
#endif
    m_intentPlaying = false;
    m_pendingPlay = false;

    QByteArray data;
    {
        StderrSilencer silencer;
        TagLib::FileRef f = makeFileRef(m_currentTrack.path);
        if (!f.isNull() && f.file()) {
            TagLib::File *file = f.file();

            if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
                if (auto *tag = mpeg->ID3v2Tag()) {
                    const auto list = tag->frameList("APIC");
                    if (!list.isEmpty()) {
                        if (auto *pic = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(list.front()))
                            data = QByteArray(pic->picture().data(), pic->picture().size());
                    }
                }
            } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
                const auto pics = flac->pictureList();
                if (!pics.isEmpty()) {
                    const auto *pic = pics.front();
                    data = QByteArray(pic->data().data(), pic->data().size());
                }
            }
        }
    }

    restorePlayer(m_currentTrack.path, savedPos, wasPlaying);

    if (data.isEmpty()) return false;
    if (QFile::exists(local)) QFile::remove(local);

    QFile out(local);
    if (!out.open(QIODevice::WriteOnly)) return false;
    out.write(data);
    return true;
}

QString Library::readTextFromTags(const QString &path) const {
    StderrSilencer silencer;
    TagLib::FileRef fr = makeFileRef(path);
    if (fr.isNull() || !fr.file()) return QString();

    TagLib::File *file = fr.file();

    if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
        if (auto *tag = mpeg->ID3v2Tag()) {
            const auto usltList = tag->frameList("USLT");
            if (!usltList.isEmpty()) {
                if (auto *frame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame*>(usltList.front())) {
                    const QString s = QString::fromUtf8(frame->text().to8Bit(true).c_str());
                    if (!s.trimmed().isEmpty()) return s;
                }
            }

            const auto txxxList = tag->frameList("TXXX");
            for (const auto &f : txxxList) {
                if (auto *frame = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame*>(f)) {
                    const QString desc = QString::fromUtf8(frame->description().to8Bit(true).c_str()).toLower();
                    if (desc.contains("lyric") || desc.contains("text")) {
                        const auto fields = frame->fieldList();
                        for (const auto &field : fields) {
                            const QString s = QString::fromUtf8(field.to8Bit(true).c_str());
                            if (s.trimmed().isEmpty()) continue;
                            if (s.toLower() == desc) continue;
                            if (s.contains('\n') || s.length() > 60) return s;
                        }
                    }
                }
            }
        }
    } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
        if (auto *xc = flac->xiphComment()) {
            const auto map = xc->fieldListMap();
            for (auto it = map.begin(); it != map.end(); ++it) {
                const QString key = QString::fromUtf8(it->first.to8Bit(true).c_str()).toLower();
                if (key.contains("lyric") || key == "text") {
                    if (!it->second.isEmpty()) {
                        const QString s = QString::fromUtf8(it->second.front().to8Bit(true).c_str());
                        if (!s.trimmed().isEmpty()) return s;
                    }
                }
            }
        }
    }

    return QString();
}

bool Library::writeTextToTags(const QString &path, const QString &content) {
    const bool isCurrentTrack = (path == m_currentTrack.path);
    const bool wasPlaying = isCurrentTrack && isPlaying();
    const qint64 savedPos = isCurrentTrack ? m_player->position() : 0;

    if (isCurrentTrack) {
        m_player->stop();
#ifdef Q_OS_WIN
        m_player->setSource(QUrl());
        waitForFileRelease(path, 2000);
#endif
        m_intentPlaying = false;
        m_pendingPlay = false;
    }

    bool ok = false;
    {
        StderrSilencer silencer;
        TagLib::FileRef fr = makeFileRef(path);
        if (!fr.isNull() && fr.file()) {
            TagLib::File *file = fr.file();

            if (auto *mpeg = dynamic_cast<TagLib::MPEG::File*>(file)) {
                TagLib::ID3v2::Tag *tag = mpeg->ID3v2Tag(true);
                if (tag) {
                    tag->removeFrames("USLT");
                    tag->removeFrames("TXXX");

                    if (!content.trimmed().isEmpty()) {
                        auto *frame = new TagLib::ID3v2::UnsynchronizedLyricsFrame;
                        frame->setLanguage("eng");
                        frame->setDescription("");
                        frame->setText(toTaglib(content));
                        tag->addFrame(frame);
                    }

                    ok = mpeg->save();
                }
            } else if (auto *flac = dynamic_cast<TagLib::FLAC::File*>(file)) {
                if (flac->xiphComment()) {
                    auto *xc = flac->xiphComment();
                    xc->removeFields("LYRICS");
                    xc->removeFields("UNSYNCEDLYRICS");
                    xc->removeFields("TEXT");

                    if (!content.trimmed().isEmpty()) {
                        xc->addField("LYRICS", toTaglib(content), true);
                    }

                    ok = flac->save();
                }
            } else {
                TagLib::Tag *tag = file->tag();
                if (tag) {
                    if (content.trimmed().isEmpty()) {
                        tag->setComment("");
                    } else {
                        tag->setComment(toTaglib(content));
                    }
                    ok = file->save();
                }
            }
        }
    }

    if (isCurrentTrack) restorePlayer(path, savedPos, wasPlaying);

    if (!ok) qWarning() << "writeTextToTags: TagLib save() failed for" << path;

    return ok;
}

QString Library::loadTrackText(int index, bool preferLrc) {
    if (index < 0 || index >= m_tracks.count()) return QString();
    const Track *t = m_tracks.at(index);
    if (!t) return QString();

    if (preferLrc) {
        const QString lrc = lyricsPath(*t, true);
        if (QFile::exists(lrc)) {
            QFile f(lrc);
            if (f.open(QIODevice::ReadOnly)) {
                const QString s = QString::fromUtf8(f.readAll());
                if (!s.trimmed().isEmpty()) return s;
            }
        }
        return QString();
    }
    return readTextFromTags(t->path);
}

bool Library::saveTrackText(int index, const QString &content, bool isLrc) {
    if (index < 0 || index >= m_tracks.count()) return false;
    const Track *t = m_tracks.at(index);
    if (!t) return false;

    if (isLrc) {
        const QString path = lyricsPath(*t, true);
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
        f.write(content.toUtf8());
        f.close();
        return true;
    }
    return writeTextToTags(t->path, content);
}

void Library::refreshLibrary() {
    if (m_folder.isEmpty()) return;

    emit refreshStarted();

    const QString curPath = m_currentTrack.path;
    const bool wasPlaying = isPlaying();
    const qint64 curPos = m_player->position();
    const bool wasCurrent = !curPath.isEmpty();

    const QStringList filters = {
        "*.mp3", "*.flac", "*.ogg", "*.opus",
        "*.wav", "*.m4a", "*.aac"
    };

    QSet<QString> existingPaths;
    existingPaths.reserve(m_allTracks.size());
    for (const Track &t : m_allTracks) existingPaths.insert(t.path);

    QSet<QString> foundPaths;
    int addedCount = 0;

    QDirIterator it(m_folder, filters, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString filePath = it.next();
        foundPaths.insert(filePath);
        if (existingPaths.contains(filePath)) continue;

        m_allTracks.append(loadOrParseTrack(filePath));
        addedCount++;
    }

    int removedCount = 0;
    bool currentRemoved = false;
    QList<Track> filtered;
    filtered.reserve(m_allTracks.size());
    for (const Track &t : m_allTracks) {
        if (foundPaths.contains(t.path)) {
            filtered.append(t);
        } else {
            if (t.path == curPath) currentRemoved = true;
            removedCount++;
        }
    }
    m_allTracks = std::move(filtered);

    updateFolderWatcher();

    if (addedCount == 0 && removedCount == 0) {
        emit refreshFinished();
        return;
    }

    rebuildArtists();
    rebuildAlbums();

    if (wasCurrent && currentRemoved) {
        m_player->stop();
        m_intentPlaying = false;
        m_pendingPlay = false;
        m_currentTrack = Track();
        m_currentIndex = -1;
        emit currentChanged();
    }

    sortAndApply(addedCount + removedCount <= 60);

    if (wasCurrent && !currentRemoved) {
        refreshCurrentIndexFromPath(curPath);
        if (wasPlaying && !isPlaying()) {
            restorePlayer(curPath, curPos, true);
        }
    }

    if (!m_activePlaylistId.isEmpty()) rebuildPlaylistTracks();

    emit trackCountChanged();
    emit currentChanged();
    emit refreshFinished();
}
