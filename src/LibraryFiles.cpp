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
        Track t;
        t.path = filePath;

        const QFileInfo info(filePath);
        t.fileSize = info.size();
        t.format = info.suffix().toUpper();

        {
            StderrSilencer silencer;
            TagLib::FileRef f = makeFileRef(filePath);
            if (!f.isNull() && f.tag()) {
                TagLib::Tag *tag = f.tag();

                const QString tagTitle  = QString::fromUtf8(tag->title().to8Bit(true).c_str());
                const QString tagArtist = QString::fromUtf8(tag->artist().to8Bit(true).c_str());
                const QString tagAlbum  = QString::fromUtf8(tag->album().to8Bit(true).c_str());

                t.title  = tagTitle.isEmpty()  ? info.completeBaseName() : tagTitle.trimmed();
                t.artist = tagArtist.isEmpty() ? "Unknown Artist" : tagArtist.trimmed();
                t.album  = tagAlbum.isEmpty()  ? "Unknown Album"  : tagAlbum.trimmed();
                t.year   = tag->year();

                if (f.audioProperties()) {
                    t.durationMs = f.audioProperties()->lengthInMilliseconds();
                    t.bitrate    = f.audioProperties()->bitrate();
                    t.sampleRate = f.audioProperties()->sampleRate();
                    t.channels   = f.audioProperties()->channels();
                }
            } else {
                t.title  = info.completeBaseName();
                t.artist = "Unknown Artist";
                t.album  = "Unknown Album";
            }
        }

        extractImages(filePath, t.cover, t.thumb);
        m_allTracks.append(t);
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
    m_customOrder.clear();
    m_showOnlyLiked = false;

    loadPlaylistOrder();

    rebuildArtists();
    rebuildAlbums();
    sortAndApply(false);
    m_searchResults.clear();

    if (!m_activePlaylistId.isEmpty()) rebuildPlaylistTracks();

    m_settings->setValue("library/folder", localPath);

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

bool Library::saveMetadata(int index,
                           const QString &title,
                           const QString &artist,
                           const QString &album,
                           const QString &coverSourcePath) {
    if (index < 0 || index >= m_tracks.count()) return false;
    const Track *old = m_tracks.at(index);
    if (!old) return false;

    const QString path = old->path;
    const bool wasCurrent = (index == m_currentIndex);
    const bool wasPlaying = isPlaying();
    const qint64 savedPos = wasCurrent ? m_player->position() : 0;

    const QString finalAlbum = album.isEmpty() ? QStringLiteral("Unknown Album") : album;

    if (wasCurrent) {
        m_player->stop();
        m_intentPlaying = false;
        m_pendingPlay = false;
        QThread::msleep(150);
    }

    const QString normalizedCover = normalizeLocalPath(coverSourcePath);
    const bool wantCover = !normalizedCover.isEmpty();

    bool ok = false;
    {
        StderrSilencer silencer;

        TagLib::FileRef fr = makeFileRef(path);
        if (fr.isNull() || !fr.file()) {
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
        if (wasCurrent) restorePlayer(path, savedPos, wasPlaying);
        return false;
    }

    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(path.toUtf8(), QCryptographicHash::Md5).toHex());
    QFile::remove(coverCacheDir() + "/" + hash + ".jpg");
    QFile::remove(thumbCacheDir() + "/" + hash + ".png");

    Track updated = *old;
    if (!title.isEmpty()) updated.title = title;
    if (!artist.isEmpty()) updated.artist = artist;
    updated.album = finalAlbum;

    QString newCover, newThumb;
    extractImages(path, newCover, newThumb);
    if (!newCover.isEmpty()) updated.cover = newCover;
    if (!newThumb.isEmpty()) updated.thumb = newThumb;

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
    m_intentPlaying = false;
    m_pendingPlay = false;
    QThread::msleep(150);

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
    m_intentPlaying = false;
    m_pendingPlay = false;
    QThread::msleep(150);

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
        m_intentPlaying = false;
        m_pendingPlay = false;
        QThread::msleep(150);
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