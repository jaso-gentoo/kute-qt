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

    void setLightTheme(bool v);
    void setMatugenEnabled(bool v);

signals:
    void changed();
    void lightThemeChanged();
    void matugenEnabledChanged();
    void matugenAvailableChanged();

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
};