#pragma once

#include <QObject>
#include <QColor>
#include <QFileSystemWatcher>

class ThemeManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QColor background     READ background     NOTIFY changed)
    Q_PROPERTY(QColor surface        READ surface        NOTIFY changed)
    Q_PROPERTY(QColor onBackground   READ onBackground   NOTIFY changed)
    Q_PROPERTY(QColor onSurface      READ onSurface      NOTIFY changed)
    Q_PROPERTY(QColor primary        READ primary        NOTIFY changed)
    Q_PROPERTY(QColor secondary      READ secondary      NOTIFY changed)
    Q_PROPERTY(QColor surfaceVariant READ surfaceVariant NOTIFY changed)
    Q_PROPERTY(QColor outline        READ outline        NOTIFY changed)
    Q_PROPERTY(bool   matugenActive  READ matugenActive  NOTIFY changed)
    Q_PROPERTY(bool   lightTheme     READ lightTheme     WRITE setLightTheme     NOTIFY lightThemeChanged)
    Q_PROPERTY(bool   matugenEnabled READ matugenEnabled WRITE setMatugenEnabled NOTIFY matugenEnabledChanged)
    Q_PROPERTY(bool   matugenAvailable READ matugenAvailable NOTIFY matugenAvailableChanged)
    Q_PROPERTY(QString renderBackend READ renderBackend WRITE setRenderBackend NOTIFY renderBackendChanged)

public:
    explicit ThemeManager(QObject *parent = nullptr);

    QColor background()     const { return m_background; }
    QColor surface()        const { return m_surface; }
    QColor onBackground()   const { return m_onBackground; }
    QColor onSurface()      const { return m_onSurface; }
    QColor primary()        const { return m_primary; }
    QColor secondary()      const { return m_secondary; }
    QColor surfaceVariant() const { return m_surfaceVariant; }
    QColor outline()        const { return m_outline; }
    bool   matugenActive()  const { return m_matugenEnabled && m_matugenAvailable; }

    bool lightTheme() const { return m_lightTheme; }
    bool matugenEnabled() const { return m_matugenEnabled; }
    bool matugenAvailable() const { return m_matugenAvailable; }
    QString renderBackend() const { return m_renderBackend; }

    void setLightTheme(bool v);
    void setMatugenEnabled(bool v);
    void setRenderBackend(const QString &v);

    Q_INVOKABLE void restartApplication();

signals:
    void changed();
    void lightThemeChanged();
    void matugenEnabledChanged();
    void matugenAvailableChanged();
    void renderBackendChanged();

private:
    void refresh();
    void applyDarkPalette();
    void applyLightPalette();
    bool loadMatugenPalette();

    QString m_filePath;
    QFileSystemWatcher m_watcher;

    QColor m_background;
    QColor m_surface;
    QColor m_onBackground;
    QColor m_onSurface;
    QColor m_primary;
    QColor m_secondary;
    QColor m_surfaceVariant;
    QColor m_outline;

    bool m_lightTheme = false;
    bool m_matugenEnabled = false;
    bool m_matugenAvailable = false;

#ifdef Q_OS_WIN
    QString m_renderBackend = "d3d11";
#else
    QString m_renderBackend = "vulkan";
#endif
};