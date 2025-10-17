import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: aboutPage
    
    // App info
    Controls.Label {
        Kirigami.FormData.label: i18n("Name:")
        text: i18nd("plasma_applet_org.kde.yourplasmoid", "Detailed Battery Monitor")
    }
    
    Controls.Label {
        Kirigami.FormData.label: i18n("Version:")
        text: "1.0.0"
    }
    
    Controls.Label {
        Kirigami.FormData.label: i18n("Description:")
        text: i18nd("plasma_applet_org.kde.yourplasmoid", "Provides detailed battery statistics")
        wrapMode: Text.WordWrap
    }
    
    Controls.Button {
        Kirigami.FormData.label: i18n("Author:")
        text: "Alfredo Monclus"
        onClicked: Qt.openUrlExternally("https://github.com/alfrix")
    }
    
    Controls.Button {
        Kirigami.FormData.label: i18n("Github")
        text: "GitHub"
        onClicked: Qt.openUrlExternally("https://github.com/alfrix/org.kde.plasma.detailedbattery/")
    }
    
    // License
    Controls.Label {
        Kirigami.FormData.label: i18n("License:")
        text: "GPL v2+"
    }
}
