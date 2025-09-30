import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Kirigami.FormLayout {
    id: page

    // Configuration property bindings
    property alias cfg_useCustomDesignCapacity: customCapacityCheck.checked
    property alias cfg_customDesignCapacity: customCapacityInput.text

    // Battery Health Section
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Battery Health Settings")
    }

    // Enable custom capacity
    PlasmaComponents.CheckBox {
        id: customCapacityCheck
        Kirigami.FormData.label: i18n("Custom capacity:")
        text: i18n("Use custom design capacity")
    }

    // Custom capacity input
    PlasmaComponents.TextField {
        id: customCapacityInput
        Kirigami.FormData.label: i18n("Design capacity:")
        enabled: customCapacityCheck.checked
        placeholderText: i18n("e.g., 47")
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        validator: DoubleValidator {
            bottom: 0
            decimals: 1
        }
    }

    // Help text
    PlasmaComponents.Label {
        Layout.fillWidth: true
        Kirigami.FormData.label: ""
        text: i18n("Set a custom design capacity in Wh if the reported battery health is inaccurate.")
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
    }
}