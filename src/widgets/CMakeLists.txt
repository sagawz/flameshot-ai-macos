add_subdirectory(panel)
add_subdirectory(capture)

# Explicit generation keeps these legacy Qt Designer forms compatible with
# newer CMake versions whose AUTOUIC scanner no longer detects the old setup.
get_target_property(QT_UIC_EXECUTABLE Qt5::uic IMPORTED_LOCATION)
foreach(UI_NAME infowindow capturelauncher uploadhistory uploadlineitem)
    execute_process(
            COMMAND ${QT_UIC_EXECUTABLE}
                    ${CMAKE_CURRENT_SOURCE_DIR}/${UI_NAME}.ui
                    -o ${CMAKE_CURRENT_BINARY_DIR}/ui_${UI_NAME}.h
            RESULT_VARIABLE UIC_RESULT)
    if (NOT UIC_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to generate ui_${UI_NAME}.h")
    endif ()
endforeach()
target_include_directories(flameshot PRIVATE ${CMAKE_CURRENT_BINARY_DIR})

# Required to generate MOC
target_sources(
        flameshot
        PRIVATE
        infowindow.ui
        capturelauncher.ui
        uploadhistory.ui
        uploadlineitem.ui

        capturelauncher.h
        draggablewidgetmaker.h
        imagelabel.h
        trayicon.h
        infowindow.h
        loadspinner.h
        notificationwidget.h
        orientablepushbutton.h
        uploadhistory.h
        uploadlineitem.h
        updatenotificationwidget.h
        colorpickerwidget.h
        imguploaddialog.h
        capture/capturetoolobjects.h
)

target_sources(
        flameshot
        PRIVATE capturelauncher.cpp
        draggablewidgetmaker.cpp
        imagelabel.cpp
        trayicon.cpp
        infowindow.cpp
        loadspinner.cpp
        notificationwidget.cpp
        orientablepushbutton.cpp
        uploadhistory.cpp
        uploadlineitem.cpp
        updatenotificationwidget.cpp
        colorpickerwidget.cpp
        imguploaddialog.cpp
        capture/capturetoolobjects.cpp
)
