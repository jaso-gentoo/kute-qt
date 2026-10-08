#include "ThemeManager.h"

#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QProcess>
#include <QCoreApplication>
#include <QTextStream>

ThemeManager::ThemeManager(QObject *parent) : QObject(parent) {
    const QString configDir =
        QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + "/kute";
    const QString matugenDir = configDir + "/matugen";
    m_filePath = matugenDir + "/kute.json";

    QDir().mkpath(matugenDir);

    QSettings s;
    m_lightTheme = s.value("ui/lightTheme", false).toBool();
    m_matugenEnabled = s.value("ui/matugenEnabled", false).toBool();
#ifdef Q_OS_WIN
    m_renderBackend = s.value("ui/renderBackend", "d3d11").toString();
#else
    m_renderBackend = s.value("ui/renderBackend", "vulkan").toString();
#endif

    if (QFile::exists(m_filePath)) {
        m_watcher.addPath(m_filePath);
        m_matugenAvailable = true;
    }
    m_watcher.addPath(matugenDir);

    connect(&m_watcher, &QFileSystemWatcher::fileChanged,
            this, [this](const QString &path) {
        if (QFile::exists(path) && !m_watcher.files().contains(path))
            m_watcher.addPath(path);
        const bool avail = QFile::exists(m_filePath);
        if (avail != m_matugenAvailable) {
            m_matugenAvailable = avail;
            emit matugenAvailableChanged();
        }
        refresh();
    });

    connect(&m_watcher, &QFileSystemWatcher::directoryChanged,
            this, [this](const QString &) {
        if (QFile::exists(m_filePath) && !m_watcher.files().contains(m_filePath))
            m_watcher.addPath(m_filePath);
        const bool avail = QFile::exists(m_filePath);
        if (avail != m_matugenAvailable) {
            m_matugenAvailable = avail;
            emit matugenAvailableChanged();
        }
        refresh();
    });

    refresh();
}

void ThemeManager::setLightTheme(bool v) {
    if (m_lightTheme == v) return;
    m_lightTheme = v;
    QSettings().setValue("ui/lightTheme", v);
    emit lightThemeChanged();
    refresh();
}

void ThemeManager::setMatugenEnabled(bool v) {
    if (m_matugenEnabled == v) return;
    m_matugenEnabled = v;
    QSettings().setValue("ui/matugenEnabled", v);
    emit matugenEnabledChanged();
    refresh();
}

void ThemeManager::setRenderBackend(const QString &v) {
    if (m_renderBackend == v) return;
    if (v != "opengl" && v != "vulkan" && v != "d3d11") return;
    m_renderBackend = v;
    QSettings().setValue("ui/renderBackend", v);
    emit renderBackendChanged();
}

void ThemeManager::restartApplication() {
    const QString program = QCoreApplication::applicationFilePath();
    QStringList args = QCoreApplication::arguments();
    if (!args.isEmpty()) args.removeFirst();

#ifdef Q_OS_WIN
    QString escaped = program;
    escaped.replace("'", "''");

    QString argString;
    for (const QString &a : args) {
        QString e = a;
        e.replace("'", "''");
        argString += " '" + e + "'";
    }

    QString script =
        "Start-Sleep -Milliseconds 900; "
        "Start-Process -FilePath '" + escaped + "'";
    if (!argString.isEmpty()) script += " -ArgumentList" + argString;

    QProcess::startDetached("powershell.exe",
        {"-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden",
         "-Command", script});
#else
    QProcess::startDetached(program, args);
#endif

    QCoreApplication::exit(0);
}

void ThemeManager::applyDarkPalette() {
    m_background     = QColor("#131316");
    m_surface        = QColor("#1a1a1e");
    m_onBackground   = QColor("#e8e8ea");
    m_onSurface      = QColor("#cecece");
    m_primary        = QColor("#b8b8c0");
    m_secondary      = QColor("#9a9aa2");
    m_surfaceVariant = QColor("#222226");
    m_outline        = QColor("#52525a");
}

void ThemeManager::applyLightPalette() {
    m_background     = QColor("#f2f2f5");
    m_surface        = QColor("#e8e8ec");
    m_onBackground   = QColor("#1a1a1c");
    m_onSurface      = QColor("#3a3a3e");
    m_primary        = QColor("#4a4a52");
    m_secondary      = QColor("#6a6a72");
    m_surfaceVariant = QColor("#dcdce2");
    m_outline        = QColor("#9a9aa2");
}

bool ThemeManager::loadMatugenPalette() {
    QFile f(m_filePath);
    if (!f.open(QIODevice::ReadOnly)) return false;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;

    const QJsonObject o = doc.object();
    auto pick = [&o](const char *key, const QColor &fallback) {
        const QString v = o.value(key).toString();
        const QColor c(v);
        return c.isValid() ? c : fallback;
    };

    m_background     = pick("background",     QColor("#131316"));
    m_surface        = pick("surface",        QColor("#1a1a1e"));
    m_onBackground   = pick("onBackground",   QColor("#e8e8ea"));
    m_onSurface      = pick("onSurface",      QColor("#cecece"));
    m_primary        = pick("primary",        QColor("#b8b8c0"));
    m_secondary      = pick("secondary",      QColor("#9a9aa2"));
    m_surfaceVariant = pick("surfaceVariant", QColor("#222226"));
    m_outline        = pick("outline",        QColor("#52525a"));
    return true;
}

void ThemeManager::refresh() {
    if (m_matugenEnabled && m_matugenAvailable) {
        if (!loadMatugenPalette()) {
            if (m_lightTheme) applyLightPalette();
            else applyDarkPalette();
        }
    } else if (m_lightTheme) {
        applyLightPalette();
    } else {
        applyDarkPalette();
    }
    emit changed();
}