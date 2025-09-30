import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Display")
        icon: "preferences-desktop-theme"
        source: "configDisplay.qml"
    }
    ConfigCategory {
        name: i18n("About")
        icon: "help-about"
        source: "configAbout.qml"
    }
}

