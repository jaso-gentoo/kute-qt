#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QKeyEvent>
#include <QQuickWindow>
#include <QQuickItem>
#include <QFile>
#include <QByteArray>
#include <cstdlib>
#include <unistd.h>
#include "ThemeManager.h"
#include "Library.h"
#include "MprisController.h"

static QByteArray selfPath() {
    return QFile::symLinkTarget("/proc/self/exe").toUtf8();
}

static void reexecWithEnv(char *argv[]) {
    if (qEnvironmentVariableIsSet("KUTE_ENV_READY")) return;
    setenv("MALLOC_ARENA_MAX", "2", 1);
    setenv("QSG_USE_IMAGE_CACHE", "0", 1);
    setenv("QSG_RENDER_LOOP", "threaded", 1);
    setenv("QSG_RHI_BACKEND", "vulkan", 1);
    setenv("QT_QUICK_BACKEND", "vulkan", 1);
    setenv("KUTE_ENV_READY", "1", 1);
    const QByteArray path = selfPath();
    if (path.isEmpty()) return;
    execv(path.constData(), argv);
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
        }

        if (!(mods & (Qt::ControlModifier | Qt::AltModifier | Qt::MetaModifier | Qt::ShiftModifier))) {
            if (!focusIsTextInput()) {
                if (k == Qt::Key_Up)    { QMetaObject::invokeMethod(m_root, "prevTrack",       Qt::DirectConnection); return true; }
                if (k == Qt::Key_Down)  { QMetaObject::invokeMethod(m_root, "nextTrack",       Qt::DirectConnection); return true; }
                if (k == Qt::Key_Left)  { QMetaObject::invokeMethod(m_root, "modalPrevSubTab", Qt::DirectConnection); return true; }
                if (k == Qt::Key_Right) { QMetaObject::invokeMethod(m_root, "modalNextSubTab", Qt::DirectConnection); return true; }
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

#include "main.moc"

int main(int argc, char *argv[]) {
    reexecWithEnv(argv);

    QGuiApplication app(argc, argv);
    app.setApplicationName("kute");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("kute");

    ThemeManager theme;
    Library library;
    MprisController mpris(&library);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("library", &library);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    engine.loadFromModule("Kute", "Main");

    if (!engine.rootObjects().isEmpty()) {
        QObject *root = engine.rootObjects().first();
        GlobalHotkeys *hk = new GlobalHotkeys(root, &app);
        app.installEventFilter(hk);
    }

    return app.exec();
}