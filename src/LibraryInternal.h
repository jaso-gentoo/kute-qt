#pragma once

#include <QString>
#include <QUrl>
#include <QDir>
#include <QStandardPaths>

#include <taglib/fileref.h>
#include <taglib/tag.h>

#ifdef Q_OS_UNIX
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>

class StderrSilencer {
public:
    StderrSilencer() {
        saved_ = dup(2);
        int nullFd = ::open("/dev/null", O_WRONLY);
        if (nullFd >= 0) {
            dup2(nullFd, 2);
            ::close(nullFd);
        }
    }
    ~StderrSilencer() {
        std::fflush(stderr);
        if (saved_ >= 0) {
            dup2(saved_, 2);
            ::close(saved_);
        }
    }
private:
    int saved_ = -1;
};
#else
class StderrSilencer {
public:
    StderrSilencer() {}
    ~StderrSilencer() {}
};
#endif

inline TagLib::String toTaglib(const QString &s) {
    const QByteArray utf8 = s.toUtf8();
    return TagLib::String(utf8.constData(), TagLib::String::UTF8);
}

inline TagLib::FileRef makeFileRef(const QString &path) {
#ifdef Q_OS_WIN
    return TagLib::FileRef(path.toStdWString().c_str());
#else
    return TagLib::FileRef(path.toUtf8().constData());
#endif
}

inline QString normalizeLocalPath(QString p) {
    if (p.startsWith("file://")) p = QUrl(p).toLocalFile();
#ifdef Q_OS_WIN
    if (p.length() >= 3 && p[0] == '/' && p[2] == ':') {
        p = p.mid(1);
    }
#endif
    return p;
}

inline QString kuteConfigDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/kute";
}

inline QString safeFileName(const QString &s) {
    QString r = s;
    r.replace('/', '_');
    r.replace('\\', '_');
    r.replace(':', '_');
    return r;
}