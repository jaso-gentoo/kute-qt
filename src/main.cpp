#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QQuickWindow>
#include <QQuickItem>
#include <QSGRendererInterface>
#include <QFile>
#include <QDir>
#include <QTextStream>
#include <QDateTime>
#include <QFontDatabase>
#include <QSettings>
#include <QTimer>
#include <exception>
#include <cstdio>

#ifndef KUTE_VERSION_STRING
#define KUTE_VERSION_STRING "v9999"
#endif

#include "ThemeManager.h"
#include "Library.h"

#ifdef Q_OS_LINUX
#include "MprisController.h"
#endif

#ifdef Q_OS_UNIX
#include <QByteArray>
#include <cstdlib>
#include <unistd.h>
#include <QFileInfo>

static QByteArray selfPath() {
    return QFile::symLinkTarget("/proc/self/exe").toUtf8();
}

static void reexecWithEnv(char *argv[]) {
    setenv("QT_LOGGING_RULES", "qt.multimedia.*=false;qt.quick.*=false", 1);
    setenv("AV_LOG_FORCE_NOCOLOR", "1", 1);
    setenv("QT_MEDIA_BACKEND", "ffmpeg", 1);
    if (qEnvironmentVariableIsSet("KUTE_ENV_READY")) return;

    setenv("MALLOC_ARENA_MAX", "2", 1);
    setenv("QSG_USE_IMAGE_CACHE", "0", 1);
    setenv("QSG_RENDER_LOOP", "threaded", 1);

    if (!qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY")) {
        setenv("QT_QPA_PLATFORM", "wayland;xcb", 1);
    }

    setenv("KUTE_ENV_READY", "1", 1);

    const QByteArray path = selfPath();
    if (path.isEmpty()) return;
    execv(path.constData(), argv);
}
#else
static void reexecWithEnv(char *argv[]) { Q_UNUSED(argv) }
#endif

#ifdef Q_OS_WIN
#include <windows.h>
#include <string>
static void enableVT() {
    HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
    if (h == INVALID_HANDLE_VALUE) return;
    DWORD mode = 0;
    if (!GetConsoleMode(h, &mode)) return;
    SetConsoleMode(h, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
}
#else
static void enableVT() {}
#endif

static QString logPath() {
    return QDir::tempPath() + "/kute_debug.log";
}

static const char *kReset  = "\033[0m";
static const char *kDebug  = "\033[90m";
static const char *kInfo   = "\033[36m";
static const char *kWarn   = "\033[33m";
static const char *kCrit   = "\033[91m";
static const char *kFatal  = "\033[97;41m";
static const char *kPlain  = "";

static const char *colorFor(QtMsgType type) {
    switch (type) {
        case QtDebugMsg:    return kDebug;
        case QtInfoMsg:     return kInfo;
        case QtWarningMsg:  return kWarn;
        case QtCriticalMsg: return kCrit;
        case QtFatalMsg:    return kFatal;
    }
    return kPlain;
}

static const char *prefixFor(QtMsgType type) {
    switch (type) {
        case QtDebugMsg:    return "DEBUG";
        case QtInfoMsg:     return "INFO ";
        case QtWarningMsg:  return "WARN ";
        case QtCriticalMsg: return "CRIT ";
        case QtFatalMsg:    return "FATAL";
    }
    return "     ";
}

static void writeToFile(const QString &line) {
    QFile f(logPath());
    if (!f.open(QIODevice::Append | QIODevice::Text)) return;
    QTextStream ts(&f);
    ts << QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss.zzz")
       << "  " << line << "\n";
    ts.flush();
}

static void writeToConsole(const QString &line, const char *color) {
    fprintf(stderr, "%s%s%s\n", color, line.toLocal8Bit().constData(), kReset);
    fflush(stderr);
}

static void emitLog(QtMsgType type, const QString &msg) {
    const QString line = QString("%1  %2").arg(prefixFor(type)).arg(msg);
    writeToFile(line);
    writeToConsole(line, colorFor(type));
}

static void msgHandler(QtMsgType type, const QMessageLogContext &, const QString &msg) {
    emitLog(type, msg);
}

static QString apiNameFrom(QSGRendererInterface::GraphicsApi api) {
    switch (api) {
        case QSGRendererInterface::OpenGL:     return "OpenGL";
        case QSGRendererInterface::Vulkan:     return "Vulkan";
        case QSGRendererInterface::Direct3D11: return "Direct3D11";
        case QSGRendererInterface::Direct3D12: return "Direct3D12";
        case QSGRendererInterface::Metal:      return "Metal";
        case QSGRendererInterface::Null:       return "Null";
        default: return QString();
    }
}

static bool focusIsTextInput() {
    QObject *focus = QGuiApplication::focusObject();
    if (!focus) return false;
    const QString cn = QString::fromLatin1(focus->metaObject()->className());
    if (!cn.contains("TextInput") && !cn.contains("TextEdit") && !cn.contains("TextField"))
        return false;
    if (auto *item = qobject_cast<QQuickItem*>(focus)) {
        return item->isVisible() && item->isEnabled();
    }
    return true;
}

class GlobalHotkeys : public QObject {
    Q_OBJECT
public:
    explicit GlobalHotkeys(QObject *root, QObject *parent = nullptr)
        : QObject(parent), m_root(root) {}

protected:
    bool eventFilter(QObject *obj, QEvent *event) override {
        if (event->type() != QEvent::KeyPress)
            return QObject::eventFilter(obj, event);

        auto *ke = static_cast<QKeyEvent*>(event);
        const int k = ke->key();
        const Qt::KeyboardModifiers mods = ke->modifiers();

        if ((mods & Qt::ControlModifier) && (mods & Qt::ShiftModifier)) {
            if (k == Qt::Key_E) {
                QMetaObject::invokeMethod(m_root, "toggleReorder", Qt::DirectConnection);
                return true;
            }
        }

        if ((mods & Qt::ControlModifier) && !(mods & Qt::ShiftModifier)) {
            if (k == Qt::Key_X) { QMetaObject::invokeMethod(m_root, "toggleMetadata",   Qt::DirectConnection); return true; }
            if (k == Qt::Key_E) { QMetaObject::invokeMethod(m_root, "toggleSettings",   Qt::DirectConnection); return true; }
            if (k == Qt::Key_F) { QMetaObject::invokeMethod(m_root, "toggleSearch",     Qt::DirectConnection); return true; }
            if (k == Qt::Key_S) { QMetaObject::invokeMethod(m_root, "handleCtrlS",      Qt::DirectConnection); return true; }
            if (k == Qt::Key_O) { QMetaObject::invokeMethod(m_root, "openFolderDialog", Qt::DirectConnection); return true; }
            if (k == Qt::Key_D) { QMetaObject::invokeMethod(m_root, "toggleLyrics",     Qt::DirectConnection); return true; }
            if (k == Qt::Key_Q) { QMetaObject::invokeMethod(m_root, "toggleInfoPanel",  Qt::DirectConnection); return true; }
            if (k == Qt::Key_1) { QMetaObject::invokeMethod(m_root, "goToHome",         Qt::DirectConnection); return true; }
            if (k == Qt::Key_2) { QMetaObject::invokeMethod(m_root, "goToArtists",      Qt::DirectConnection); return true; }
            if (k == Qt::Key_W) { QMetaObject::invokeMethod(m_root, "toggleCurrentLike",Qt::DirectConnection); return true; }
        }

        if (!(mods & (Qt::ControlModifier | Qt::AltModifier | Qt::MetaModifier | Qt::ShiftModifier))) {
            if (!focusIsTextInput()) {
                if (k == Qt::Key_Up)    { QMetaObject::invokeMethod(m_root, "prevTrack",     Qt::DirectConnection); return true; }
                if (k == Qt::Key_Down)  { QMetaObject::invokeMethod(m_root, "nextTrack",     Qt::DirectConnection); return true; }
                if (k == Qt::Key_Left)  { QMetaObject::invokeMethod(m_root, "seekBackward",  Qt::DirectConnection); return true; }
                if (k == Qt::Key_Right) { QMetaObject::invokeMethod(m_root, "seekForward",   Qt::DirectConnection); return true; }
            }
        }

        if (k == Qt::Key_Space && mods == Qt::NoModifier) {
            if (focusIsTextInput())
                return QObject::eventFilter(obj, event);
            QMetaObject::invokeMethod(m_root, "togglePlayPause", Qt::DirectConnection);
            return true;
        }

        return QObject::eventFilter(obj, event);
    }

private:
    QObject *m_root;
};

class GlobalClickMonitor : public QObject {
    Q_OBJECT
public:
    explicit GlobalClickMonitor(QObject *root, QObject *parent = nullptr)
        : QObject(parent), m_root(root) {}

protected:
    bool eventFilter(QObject *obj, QEvent *event) override {
        if (event->type() == QEvent::MouseButtonRelease) {
            if (!m_root->property("floatingSearchOpen").toBool())
                return QObject::eventFilter(obj, event);
            auto *me = static_cast<QMouseEvent*>(event);
            if (me->button() == Qt::LeftButton) {
                const QPointF p = me->position();
                QMetaObject::invokeMethod(m_root, "handleGlobalClick",
                    Qt::DirectConnection,
                    Q_ARG(QVariant, QVariant(p.x())),
                    Q_ARG(QVariant, QVariant(p.y())));
            }
        }
        return QObject::eventFilter(obj, event);
    }
private:
    QObject *m_root;
};

#ifdef Q_OS_WIN

static void setupDllSearchPath() {
    SetDefaultDllDirectories(
        LOAD_LIBRARY_SEARCH_APPLICATION_DIR |
        LOAD_LIBRARY_SEARCH_SYSTEM32 |
        LOAD_LIBRARY_SEARCH_USER_DIRS);

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString mmDir = appDir + "/multimedia";

    const std::wstring appW = QDir::toNativeSeparators(appDir).toStdWString();
    const std::wstring mmW  = QDir::toNativeSeparators(mmDir).toStdWString();

    SetCurrentDirectoryW(appW.c_str());

    if (AddDllDirectory(appW.c_str())) {
        emitLog(QtInfoMsg, QString("AddDllDirectory OK: %1").arg(appDir));
    } else {
        emitLog(QtWarningMsg, QString("AddDllDirectory FAILED: %1 (err=%2)")
            .arg(appDir).arg(GetLastError()));
    }

    if (AddDllDirectory(mmW.c_str())) {
        emitLog(QtInfoMsg, QString("AddDllDirectory OK: %1").arg(mmDir));
    } else {
        emitLog(QtWarningMsg, QString("AddDllDirectory FAILED: %1 (err=%2)")
            .arg(mmDir).arg(GetLastError()));
    }
}

#else
static void setupDllSearchPath() {}
#endif

#include "main.moc"

int main(int argc, char *argv[]) {
    enableVT();
    qInstallMessageHandler(msgHandler);

    {
        QFile f(logPath());
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        }
        f.close();
    }

    emitLog(QtInfoMsg, "================ kute starting ================");
    emitLog(QtInfoMsg, QString("argc=%1").arg(argc));
    emitLog(QtInfoMsg, QString("tempDir=%1").arg(QDir::tempPath()));
    emitLog(QtInfoMsg, QString("exePath=%1").arg(QString::fromLocal8Bit(argv[0])));
    emitLog(QtInfoMsg, QString("Qt version=%1").arg(QT_VERSION_STR));

    try {
        reexecWithEnv(argv);
        emitLog(QtInfoMsg, "after reexecWithEnv");

        qputenv("QT_MEDIA_BACKEND", "ffmpeg");
        emitLog(QtInfoMsg, "media backend: ffmpeg");

        QSettings rhiSettings("kute", "kute");
#ifdef Q_OS_WIN
        const QString defaultBackend = "d3d11";
#else
        const QString defaultBackend = "vulkan";
#endif
        const QString rhiBackend = rhiSettings.value("ui/renderBackend", defaultBackend).toString();
        if (rhiBackend == "opengl") {
            qputenv("QSG_RHI_BACKEND", "opengl");
            emitLog(QtInfoMsg, "RHI backend: opengl");
        } else if (rhiBackend == "d3d11") {
            qputenv("QSG_RHI_BACKEND", "d3d11");
            emitLog(QtInfoMsg, "RHI backend: d3d11");
        } else {
            qputenv("QSG_RHI_BACKEND", "vulkan");
            emitLog(QtInfoMsg, "RHI backend: vulkan");
        }

        QGuiApplication app(argc, argv);
        emitLog(QtInfoMsg, "QGuiApplication constructed");
        emitLog(QtInfoMsg, QString("platform=%1").arg(app.platformName()));

        emitLog(QtInfoMsg, "setting up DLL search path");
        setupDllSearchPath();

        const int fontId = QFontDatabase::addApplicationFont(":/fonts/MaterialSymbolsRounded.ttf");
        emitLog(QtInfoMsg, QString("addApplicationFont returned fontId=%1").arg(fontId));
        if (fontId >= 0) {
            const QStringList families = QFontDatabase::applicationFontFamilies(fontId);
            emitLog(QtInfoMsg, QString("Material font loaded: %1").arg(families.join(", ")));
        } else {
            emitLog(QtWarningMsg, "Material Symbols Rounded font not loaded");
        }

        app.setApplicationName("kute");
        app.setApplicationVersion(QStringLiteral(KUTE_VERSION_STRING));
        app.setOrganizationName("kute");

        emitLog(QtInfoMsg, QString("kute version: %1").arg(app.applicationVersion()));

        emitLog(QtInfoMsg, "creating ThemeManager");
        ThemeManager theme;

        emitLog(QtInfoMsg, "creating Library");
        Library library;

#ifdef Q_OS_LINUX
        emitLog(QtInfoMsg, "creating MprisController");
        MprisController mpris(&library);
#endif

        emitLog(QtInfoMsg, "creating QQmlApplicationEngine");
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("theme", &theme);
        engine.rootContext()->setContextProperty("library", &library);

        QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                         &app, []() {
            emitLog(QtCriticalMsg, "QML objectCreationFailed signal");
            QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);

        emitLog(QtInfoMsg, "loading QML module Kute/Main");
        engine.loadFromModule("Kute", "Main");
        emitLog(QtInfoMsg, QString("loadFromModule returned, rootObjects=%1")
                  .arg(engine.rootObjects().size()));

        if (engine.rootObjects().isEmpty()) {
            emitLog(QtCriticalMsg, "FATAL: rootObjects is empty — QML did not load");
            return 1;
        }

        QObject *root = engine.rootObjects().first();

        if (auto *win = qobject_cast<QQuickWindow*>(root)) {
            win->setPersistentGraphics(false);
            win->setPersistentSceneGraph(false);
            emitLog(QtInfoMsg, "persistent graphics disabled");

            auto tryUpdate = [win]() -> bool {
                if (!win->property("activeRenderer").toString().isEmpty()) return true;
                if (auto *ri = win->rendererInterface()) {
                    const QString name = apiNameFrom(ri->graphicsApi());
                    if (!name.isEmpty()) {
                        win->setProperty("activeRenderer", name);
                        emitLog(QtInfoMsg, QString("Active renderer: %1").arg(name));
                        return true;
                    }
                }
                return false;
            };

            QObject::connect(win, &QQuickWindow::sceneGraphInitialized, win, [tryUpdate]() {
                tryUpdate();
            });

            QTimer::singleShot(300, win, [tryUpdate]() { tryUpdate(); });
            QTimer::singleShot(1000, win, [tryUpdate]() { tryUpdate(); });
            QTimer::singleShot(2500, win, [tryUpdate]() { tryUpdate(); });
        }

        emitLog(QtInfoMsg, "installing GlobalHotkeys");
        GlobalHotkeys *hk = new GlobalHotkeys(root, &app);
        app.installEventFilter(hk);

        emitLog(QtInfoMsg, "installing GlobalClickMonitor");
        GlobalClickMonitor *cm = new GlobalClickMonitor(root, &app);
        app.installEventFilter(cm);

        emitLog(QtInfoMsg, "entering event loop");
        const int rc = app.exec();
        emitLog(QtInfoMsg, QString("event loop exited with code %1").arg(rc));
        return rc;

    } catch (const std::exception &e) {
        emitLog(QtCriticalMsg, QString("EXCEPTION: %1").arg(e.what()));
        return 2;
    } catch (...) {
        emitLog(QtCriticalMsg, "UNKNOWN EXCEPTION");
        return 3;
    }
}
