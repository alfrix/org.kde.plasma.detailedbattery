import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Import the private battery components that work in Plasma 6
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.battery

PlasmoidItem {
    id: root

    // Use the BatteryControlModel from the private API
    BatteryControlModel {
        id: batteryControl
        readonly property int remainingTime: smoothedRemainingMsec
        readonly property bool isSomehowFullyCharged: pluggedIn && state === BatteryControlModel.FullyCharged
    }

    // Elapsed time tracking
    property int elapsedSeconds: 0
    property bool wasPluggedIn: batteryControl.pluggedIn

    // Update timer
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            updateElapsedTime()
        }
    }

    function updateElapsedTime() {
        // Reset elapsed time when plug state changes
        if (wasPluggedIn !== batteryControl.pluggedIn) {
            elapsedSeconds = 0
            wasPluggedIn = batteryControl.pluggedIn
        } else {
            elapsedSeconds++
        }
    }

    function formatElapsedTime(seconds) {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        const secs = seconds % 60

        if (hours > 0) {
            return hours + "h " + minutes + "m "
        } else if (minutes > 0) {
            return minutes + "m "
        } else {
            return secs + "s"
        }
    }

    compactRepresentation: Item {
        Layout.preferredWidth: batteryRow.implicitWidth
        Layout.preferredHeight: batteryRow.implicitHeight

        RowLayout {
            id: batteryRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: getBatteryIconName()
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
            }

            PlasmaComponents.Label {
                text: getBatteryText()
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium * 3
        spacing: Kirigami.Units.smallSpacing

        // First row: Battery status
        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: getBatteryIconName()
                width: Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
            }

            PlasmaComponents.Label {
                text: getBatteryText()
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                Layout.fillWidth: true
            }
        }

        // Second row: Remaining time
        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            visible: batteryControl.hasBatteries

            Kirigami.Icon {
                source: "chronometer-symbolic"
                width: Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
            }

            PlasmaComponents.Label {
                text: getTimeText()
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                Layout.fillWidth: true
            }
        }

        // Third row: Elapsed time
        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            visible: batteryControl.hasBatteries

            Kirigami.Icon {
                source: "chronometer-symbolic"
                width: Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
            }

            PlasmaComponents.Label {
                text: getElapsedTimeText()
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                Layout.fillWidth: true
            }
        }
        // Fourth row: Voltage
        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            visible: batteryControl.hasBatteries && voltage > 0

            Kirigami.Icon {
                source: "energy-voltage-symbolic" // or "battery-symbolic"
                width: Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
            }

            PlasmaComponents.Label {
                text: voltage.toFixed(1) + " V"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                Layout.fillWidth: true
            }
        }
        // Fifth row: Power
        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            visible: batteryControl.hasBatteries && power > 0

            Kirigami.Icon {
                source: "energy-power-symbolic" // or "flash-symbolic"
                width: Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
            }

            PlasmaComponents.Label {
                text: power.toFixed(1) + " W"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                Layout.fillWidth: true
            }
        }
    }

    toolTipMainText: getBatteryText()
    toolTipSubText: {
        var parts = []
        if (batteryControl.hasBatteries) {
            parts.push(getTimeText())
        }
        if (batteryControl.hasBatteries) {
            parts.push(getElapsedTimeText())
        }
        return parts.join("\n")
    }

    // Helper functions
    function getBatteryIconName() {
        if (!batteryControl.hasBatteries) return "dialog-close-symbolic"

        const percent = batteryControl.percent
        const pluggedIn = batteryControl.pluggedIn
        const state = batteryControl.state

        var levelSuffix = "100"
        if (percent <= 10) levelSuffix = "010"
        else if (percent <= 20) levelSuffix = "020"
        else if (percent <= 30) levelSuffix = "030"
        else if (percent <= 40) levelSuffix = "040"
        else if (percent <= 50) levelSuffix = "050"
        else if (percent <= 60) levelSuffix = "060"
        else if (percent <= 70) levelSuffix = "070"
        else if (percent <= 80) levelSuffix = "080"
        else if (percent <= 90) levelSuffix = "090"

        var iconName = "battery-" + levelSuffix

        if (pluggedIn && state === BatteryControlModel.Charging) {
            iconName += "-charging"
        }

        return iconName + "-symbolic"
    }

    function getBatteryText() {
        if (!batteryControl.hasBatteries) return "No battery"

        const percent = batteryControl.percent
        if (batteryControl.isSomehowFullyCharged) return percent + "% Charged"
        if (batteryControl.pluggedIn) {
            if (batteryControl.state === BatteryControlModel.Charging) return percent + "% Charging"
            if (batteryControl.state === BatteryControlModel.Discharging) return percent + "% Plugged in"
            return percent + "% Not charging"
        }
        return percent + "% Discharging"
    }

    property string lastValidRemainingTime: ""

    function getTimeText() {
        if (batteryControl.remainingTime <= 0) {
            if (batteryControl.pluggedIn && batteryControl.percent == 100) {
                return "Fully Charged"
            }
            if (lastValidRemainingTime !== "") {
                return lastValidRemainingTime
            }
            return "Calculating remaining time"
        }

        const seconds = Math.floor(batteryControl.remainingTime / 1000)
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)

        if (batteryControl.pluggedIn && batteryControl.state === BatteryControlModel.Charging) {
            if (hours > 0) {
                lastValidRemainingTime = hours + "h " + minutes + "m until full"
            } else {
                lastValidRemainingTime = minutes + "m until full"
            }
        } else {
            if (hours > 0) {
                lastValidRemainingTime = hours + "h " + minutes + "m remaining"
            } else {
                lastValidRemainingTime = minutes + "m remaining"
            }
        }
        return lastValidRemainingTime
    }

    function getElapsedTimeText() {
        if (elapsedSeconds < 0) elapsedSeconds = 0

        if (batteryControl.pluggedIn) {
            return formatElapsedTime(elapsedSeconds) + " since plugged"
        } else {
            return formatElapsedTime(elapsedSeconds) + " since unplugged"
        }
    }

    // Initialize elapsed time tracking
    Component.onCompleted: {
        wasPluggedIn = batteryControl.pluggedIn
    }
}