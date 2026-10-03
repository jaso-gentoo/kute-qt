cmake_minimum_required(VERSION 3.20)
project(kute VERSION 1.0.0 LANGUAGES CXX)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

set(QT_COMPONENTS Core Gui Quick QuickControls2 Multimedia Network)
if(UNIX AND NOT APPLE)
    list(APPEND QT_COMPONENTS DBus)
endif()
find_package(Qt6 6.5 REQUIRED COMPONENTS ${QT_COMPONENTS})

if(WIN32)
    find_package(TagLib REQUIRED)
    set(TAGLIB_LINK TagLib::TagLib)
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)
    set(TAGLIB_LINK PkgConfig::TAGLIB)
endif()

qt_standard_project_setup()

set(SOURCES
    src/main.cpp
    src/ThemeManager.cpp
    src/TrackModel.cpp
    src/Library.cpp
    src/DiscordRPC.cpp
)
if(UNIX AND NOT APPLE)
    list(APPEND SOURCES src/MprisController.cpp)
endif()

qt_add_executable(kute ${SOURCES})

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
    ${TAGLIB_LINK}
)

if(UNIX AND NOT APPLE)
    target_link_libraries(kute PRIVATE Qt6::DBus)
endif()

if(WIN32)
    set_target_properties(kute PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)
    install(TARGETS kute RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    if(EXISTS "${CMAKE_SOURCE_DIR}/packaging/kute.desktop")
        install(FILES packaging/kute.desktop
                DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)
    endif()
    if(EXISTS "${CMAKE_SOURCE_DIR}/packaging/kute.png")
        install(FILES packaging/kute.png
                DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/256x256/apps)
    endif()
endif()