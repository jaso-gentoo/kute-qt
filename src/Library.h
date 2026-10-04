#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QHash>
#include <QSet>
#include <QMediaPlayer>
#include <QAudioOutput>
#include "TrackModel.h"
#include "DiscordRPC.h"

class QTimer;

class Library : public QObject {
    Q_OBJECT
    Q_PROPERTY(TrackModel* tracks        READ tracks        CONSTANT)
    Q_PROPERTY(TrackModel* searchResults READ searchResults CONSTANT)
    Q_PROPERTY(QString     folder      READ folder      NOTIFY folderChanged)
    Q_PROPERTY(QString     folderName  READ folderName  NOTIFY folderChanged)
    Q_PROPERTY(int         trackCount  READ trackCount  NOTIFY trackCountChanged)
    Q_PROPERTY(int         currentIndex READ currentIndex NOTIFY currentChanged)
    Q_PROPERTY(QString     currentTitle      READ currentTitle      NOTIFY currentChanged)
    Q_PROPERTY(QString     currentArtist     READ currentArtist     NOTIFY currentChanged)
    Q_PROPERTY(QString     currentAlbum      READ currentAlbum      NOTIFY currentChanged)
    Q_PROPERTY(QString     currentCover      READ currentCover      NOTIFY currentChanged)
    Q_PROPERTY(QString     currentFormat     READ currentFormat     NOTIFY currentChanged)
    Q_PROPERTY(QString     currentFilePath   READ currentFilePath   NOTIFY currentChanged)
    Q_PROPERTY(int         currentBitrate    READ currentBitrate    NOTIFY currentChanged)
    Q_PROPERTY(int         currentSampleRate READ currentSampleRate NOTIFY currentChanged)
    Q_PROPERTY(int         currentChannels   READ currentChannels   NOTIFY currentChanged)
    Q_PROPERTY(int         currentYear       READ currentYear       NOTIFY currentChanged)
    Q_PROPERTY(qint64      currentFileSize   READ currentFileSize   NOTIFY currentChanged)
    Q_PROPERTY(qint64      currentTrackDuration READ currentTrackDuration NOTIFY currentChanged)
    Q_PROPERTY(bool        hasCurrent    READ hasCurrent    NOTIFY currentChanged)
    Q_PROPERTY(bool        isPlaying     READ isPlaying     NOTIFY isPlayingChanged)
    Q_PROPERTY(qint64      position      READ position      NOTIFY positionChanged)
    Q_PROPERTY(qint64      duration      READ duration      NOTIFY durationChanged)
    Q_PROPERTY(int         volume        READ volume        WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString     sortField     READ sortField     NOTIFY sortChanged)
    Q_PROPERTY(bool        sortAscending READ sortAscending NOTIFY sortChanged)
    Q_PROPERTY(bool        infoPanelVisible READ infoPanelVisible WRITE setInfoPanelVisible NOTIFY infoPanelVisibleChanged)
    Q_PROPERTY(QStringList artists       READ artists       NOTIFY artistsChanged)
    Q_PROPERTY(QString     filterArtist  READ filterArtist  NOTIFY filterArtistChanged)
    Q_PROPERTY(QString     filterText    READ filterText    WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(QString     searchQuery   READ searchQuery   NOTIFY searchQueryChanged)
    Q_PROPERTY(int         repeatMode    READ repeatMode    NOTIFY repeatModeChanged)
    Q_PROPERTY(bool        discordRpcEnabled READ discordRpcEnabled WRITE setDiscordRpcEnabled NOTIFY discordRpcEnabledChanged)
    Q_PROPERTY(bool        discordConnected  READ discordConnected  NOTIFY discordConnectedChanged)
    Q_PROPERTY(QString     osName        READ osName        CONSTANT)
    Q_PROPERTY(bool        reorderMode   READ reorderMode   NOTIFY reorderModeChanged)
    Q_PROPERTY(int         coverVersion  READ coverVersion  NOTIFY coverVersionChanged)
    Q_PROPERTY(int         offsetRevision READ offsetRevision NOTIFY offsetRevisionChanged)
    Q_PROPERTY(int         likedCount    READ likedCount    NOTIFY likedChanged)
    Q_PROPERTY(int         likedRevision READ likedRevision NOTIFY likedChanged)
    Q_PROPERTY(bool        showOnlyLiked READ showOnlyLiked WRITE setShowOnlyLiked NOTIFY showOnlyLikedChanged)

public:
    explicit Library(QObject *parent = nullptr);

    TrackModel* tracks()        { return &m_tracks; }
    TrackModel* searchResults() { return &m_searchResults; }
    QString     folder() const     { return m_folder; }
    QString     folderName() const;
    int         trackCount() const { return m_tracks.count(); }

    int     currentIndex() const { return m_currentIndex; }
    QString currentTitle()      const { return m_currentTrack.title; }
    QString currentArtist()     const { return m_currentTrack.artist; }
    QString currentAlbum()      const { return m_currentTrack.album; }
    QString currentCover()      const { return m_currentTrack.cover; }
    QString currentFormat()     const { return m_currentTrack.format; }
    QString currentFilePath()   const { return m_currentTrack.path; }
    int     currentBitrate()    const { return m_currentTrack.bitrate; }
    int     currentSampleRate() const { return m_currentTrack.sampleRate; }
    int     currentChannels()   const { return m_currentTrack.channels; }
    int     currentYear()       const { return m_currentTrack.year; }
    qint64  currentFileSize()   const { return m_currentTrack.fileSize; }
    qint64  currentTrackDuration() const { return m_currentTrack.durationMs; }
    bool    hasCurrent()        const { return !m_currentTrack.path.isEmpty(); }

    bool   isPlaying() const;
    qint64 position()  const;
    qint64 duration()  const;
    int    volume()    const;

    QString sortField()     const { return m_sortField; }
    bool    sortAscending() const { return m_sortAscending; }

    bool infoPanelVisible() const { return m_infoPanelVisible; }
    void setInfoPanelVisible(bool v);

    QStringList artists() const { return m_artists; }
    QString filterArtist() const { return m_filterArtist; }
    QString filterText()   const { return m_filterText; }
    QString searchQuery()  const { return m_searchQuery; }

    int repeatMode() const { return m_repeatMode; }
    bool reorderMode() const { return m_reorderMode; }
    int coverVersion() const { return m_coverVersion; }
    int offsetRevision() const { return m_offsetRevision; }
    int likedCount() const { return m_likedPaths.size(); }
    int likedRevision() const { return m_likedRevision; }
    bool showOnlyLiked() const { return m_showOnlyLiked; }
    void setShowOnlyLiked(bool v);

    bool discordRpcEnabled() const;
    void setDiscordRpcEnabled(bool v);
    bool discordConnected()  const;

    QString osName() const { return m_osName; }

    Q_INVOKABLE void loadFolder(const QString &path);
    Q_INVOKABLE void playIndex(int index);
    Q_INVOKABLE void playSearchIndex(int index);
    Q_INVOKABLE void setCurrent(int index);
    Q_INVOKABLE void togglePlayPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void prev();
    Q_INVOKABLE void seek(qint64 pos);
    Q_INVOKABLE void applySort(const QString &field, bool ascending);
    Q_INVOKABLE void setFilterArtist(const QString &artist);
    Q_INVOKABLE void clearFilter();
    Q_INVOKABLE void setSearch(const QString &q);
    Q_INVOKABLE void setFilterText(const QString &t);
    Q_INVOKABLE void cycleRepeat();
    Q_INVOKABLE void toggleReorderMode();
    Q_INVOKABLE void moveTrack(int from, int to);
    Q_INVOKABLE void savePlaylistOrder();
    Q_INVOKABLE bool saveMetadata(int index,
                                  const QString &title,
                                  const QString &artist,
                                  const QString &album,
                                  const QString &coverSourcePath);
    Q_INVOKABLE bool removeCurrentCover();
    Q_INVOKABLE bool saveCoverTo(const QString &destPath);
    Q_INVOKABLE QString loadTrackText(int index, bool preferLrc);
    Q_INVOKABLE bool saveTrackText(int index, const QString &content, bool isLrc);
    Q_INVOKABLE double getLrcOffset(int index) const;
    Q_INVOKABLE void setLrcOffset(int index, double value);
    Q_INVOKABLE bool isLiked(int index) const;
    Q_INVOKABLE bool isCurrentLiked() const;
    Q_INVOKABLE void toggleLike(int index);
    Q_INVOKABLE void toggleCurrentLike();
    Q_INVOKABLE QString toFileUrl(const QString &localPath) const;
    void setVolume(int v);

    Q_INVOKABLE QString formatDuration(qint64 ms) const;
    Q_INVOKABLE QString formatFileSize(qint64 bytes) const;
    Q_INVOKABLE QString formatSampleRate(int hz) const;
    QMediaPlayer* player() const { return m_player; }

signals:
    void folderChanged();
    void trackCountChanged();
    void currentChanged();
    void isPlayingChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void sortChanged();
    void infoPanelVisibleChanged();
    void artistsChanged();
    void filterArtistChanged();
    void filterTextChanged();
    void searchQueryChanged();
    void repeatModeChanged();
    void discordRpcEnabledChanged();
    void discordConnectedChanged();
    void reorderModeChanged();
    void coverVersionChanged();
    void offsetRevisionChanged();
    void likedChanged();
    void showOnlyLikedChanged();

private slots:
    void flushPresence();
    void flushOffsetSave();
    void flushLikedSave();

private:
    QString coverCacheDir() const;
    QString thumbCacheDir() const;
    QString lyricsDir() const;
    QString lyricsPath(const Track &t, bool lrc) const;
    QString safeName(const QString &s) const;
    QString readTextFromTags(const QString &path) const;
    bool    writeTextToTags(const QString &path, const QString &content);
    QString offsetsPath() const;
    void    loadOffsets();
    void    saveOffsets();
    QString likedPath() const;
    void    loadLiked();
    void    saveLiked();
    void    extractImages(const QString &filePath, QString &coverOut, QString &thumbOut) const;
    void    sortAndApply(bool animate = true);
    void    loadPlaylistOrder();
    void    savePlaylistOrderNow();
    QString playlistOrderPath() const;
    void    rebuildArtists();
    void    rebuildSearch();
    void    startTrack(const Track &t);
    void    schedulePresence();

    TrackModel    m_tracks;
    TrackModel    m_searchResults;
    QList<Track>  m_allTracks;
    QString       m_folder;
    int           m_currentIndex = -1;
    Track         m_currentTrack;
    QMediaPlayer *m_player = nullptr;
    QAudioOutput *m_audioOutput = nullptr;
    DiscordRPC   *m_rpc = nullptr;
    QTimer       *m_presenceTimer = nullptr;
    QTimer       *m_offsetSaveTimer = nullptr;
    QTimer       *m_likedSaveTimer = nullptr;

    QString m_sortField = "path";
    bool    m_sortAscending = true;
    bool    m_infoPanelVisible = true;
    QStringList m_artists;
    QString m_filterArtist;
    QString m_filterText;
    QString m_searchQuery;
    int     m_repeatMode = 0;
    bool    m_reorderMode = false;
    QStringList m_customOrder;
    QString m_osName;
    bool    m_intentPlaying = false;
    qint64  m_lastPresenceSent = 0;
    int     m_coverVersion = 0;
    int     m_offsetRevision = 0;
    QHash<QString, double> m_lrcOffsets;
    QSet<QString> m_likedPaths;
    int     m_likedRevision = 0;
    bool    m_showOnlyLiked = false;
};