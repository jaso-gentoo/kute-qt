cmake_minimum_required(VERSION 3.20)
project(kute VERSION 1.0.0 LANGUAGES CXX)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Multimedia Network DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)

qt_standard_project_setup()

qt_add_executable(kute
    src/main.cpp
    src/ThemeManager.cpp
    src/TrackModel.cpp
    src/Library.cpp
    src/DiscordRPC.cpp
    src/MprisController.cpp
)

qt_add_qml_module(kute
    URI Kute
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    NO_PLUGIN
    QML_FILES
        qml/Main.qml
        qml/MaterialIcon.qml
        qml/NavRail.qml
        qml/InfoPanel.qml
        qml/BottomBar.qml
        qml/PlaylistView.qml
        qml/ArtistsView.qml
        qml/SettingsModal.qml
        qml/SettingsTab.qml
        qml/TrackTab.qml
        qml/LyricsTab.qml
        qml/FloatingSearch.qml
)

target_link_libraries(kute PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
    Qt6::Network
    Qt6::DBus
    PkgConfig::TAGLIB
)