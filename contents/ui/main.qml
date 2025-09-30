import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support

// Import the private battery components that work in Plasma 6
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.battery

PlasmoidItem {
    id: root

    // --- Plasmoid Configuration ---
    BatteryControlModel {
        id: batteryControl
    }

    // --- Configuration ---
    property bool useCustomDesignCapacity: plasmoid.configuration.useCustomDesignCapacity
    property real customDesignCapacity: plasmoid.configuration.customDesignCapacity

    // --- UPower-based metrics ---
    property string batteryDevice: ""
    property real voltageVolts: 0.0
    property real powerWatts: 0.0
    property real currentAmps: 0.0
    property real energyFullDesignWh: 0.0
    property real energyFullWh: 0.0
    property real energyNowWh: 0.0
    property real timeToEmptySeconds: 0.0
    property real timeToFullSeconds: 0.0

    // --- Averaging for better estimates ---
    property var timeEstimateHistory: []
    property var powerHistory: []
    property int updateIntervalSecs: 2
    property int maxHistorySize: 60 / updateIntervalSecs
    property real lastStableTimeEstimate: 0
    property int lastStableTimeEstimateType: 0 // 0 = timeToEmpty, 1 = timeToFull

    // --- Elapsed time tracking ---
    property int elapsedSeconds: 0
    property bool wasPluggedIn: batteryControl.pluggedIn
    property string lastPlugChangeTime: plasmoid.configuration.lastPlugChangeTime
    property int savedElapsedSeconds: plasmoid.configuration.savedElapsedSeconds

    // --- UPower Data Source ---
    P5Support.DataSource {
        id: upowerDataSource
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data["exit code"] === 0 && data.stdout) {
                if (sourceName.includes("upower -e")) {
                    parseBatteryList(data.stdout)
                } else if (sourceName.includes("upower -i")) {
                    parseBatteryInfo(data.stdout)
                }
            }
            disconnectSource(sourceName)
        }

        function getBatteryList() {
            connectSource("upower -e | grep BAT")
        }

        function getBatteryInfo() {
            if (batteryDevice !== "") {
                connectSource("upower -i " + batteryDevice)
            } else {
                connectSource("upower -i $(upower -e | grep BAT | head -n1)")
            }
        }
    }

    // --- Timers ---
    Timer {
        id: elapsedTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateElapsedTime()
    }

    Timer {
        id: batteryUpdateTimer
        interval: updateIntervalSecs * 1000
        running: true
        repeat: true
        onTriggered: updateBatteryData()
    }

    // --- Core Functions ---
    function updateElapsedTime() {
        if (wasPluggedIn !== batteryControl.pluggedIn) {
            // Plug state changed - save the timestamp
            var now = new Date()
            lastPlugChangeTime = now.toISOString()
            plasmoid.configuration.lastPlugChangeTime = lastPlugChangeTime
            elapsedSeconds = 0
            plasmoid.configuration.savedElapsedSeconds = 0
            wasPluggedIn = batteryControl.pluggedIn
        } else {
            // Update elapsed time based on current interval
            if (elapsedTimer.interval === 1000) {
                elapsedSeconds++
            } else {
                elapsedSeconds += 60
            }
            plasmoid.configuration.savedElapsedSeconds = elapsedSeconds

            // Adaptive interval switching
            if (elapsedTimer.interval === 1000 && elapsedSeconds >= 60) {
                elapsedTimer.interval = 60000
            } else if (elapsedTimer.interval === 60000 && elapsedSeconds < 60) {
                elapsedTimer.interval = 1000
            }
        }
    }

    function restoreElapsedTime() {
        if (lastPlugChangeTime) {
            var savedTime = new Date(lastPlugChangeTime)
            var now = new Date()
            var diffSeconds = Math.floor((now - savedTime) / 1000)

            // Only restore if it's reasonable (less than 1 week)
            if (diffSeconds > 0 && diffSeconds < 604800) {
                elapsedSeconds = diffSeconds
            } else {
                // Invalid saved time, reset
                lastPlugChangeTime = ""
                plasmoid.configuration.lastPlugChangeTime = ""
                elapsedSeconds = 0
            }
        }
    }

    function updateBatteryData() {
        upowerDataSource.getBatteryList()
    }

    function parseBatteryList(output) {
        if (!output || output.trim() === "") return

        var lines = output.trim().split('\n')
        if (lines.length > 0 && lines[0] !== "") {
            batteryDevice = lines[0].trim()
            upowerDataSource.getBatteryInfo()
        }
    }

    function parseBatteryInfo(output) {
        if (!output || output.trim() === "") return

        var lines = output.trim().split('\n')
        var data = {}

        // Parse UPower output
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "" || !line.includes(':')) continue

            var colonIndex = line.indexOf(':')
            var key = line.substring(0, colonIndex).trim().toLowerCase().replace(/\s+/g, ' ')
            var value = line.substring(colonIndex + 1).trim()
            data[key] = value
        }

        // Extract energy data
        if (data["energy"]) {
            var energyStr = data["energy"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            energyNowWh = parseFloat(energyStr) || energyNowWh
        }

        if (data["energy-full"]) {
            var energyFullStr = data["energy-full"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            energyFullWh = parseFloat(energyFullStr) || energyFullWh
        }

        if (data["energy-full-design"]) {
            var energyFullDesignStr = data["energy-full-design"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            energyFullDesignWh = parseFloat(energyFullDesignStr) || energyFullDesignWh
        }

        // Extract voltage
        if (data["voltage"]) {
            var voltageStr = data["voltage"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            voltageVolts = parseFloat(voltageStr) || voltageVolts
        }

        // Extract power and calculate current
        if (data["energy-rate"]) {
            var powerStr = data["energy-rate"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            powerWatts = parseFloat(powerStr) || powerWatts

            // Calculate current from power and voltage
            if (voltageVolts > 0) {
                currentAmps = powerWatts / voltageVolts
                // Make current negative during discharge
                if (!batteryControl.pluggedIn && currentAmps > 0) {
                    currentAmps = -currentAmps
                }
            }
        }

        // Extract UPower's time estimates (most reliable)
        if (data["time to empty"]) {
            timeToEmptySeconds = parseTimeString(data["time to empty"])
        }

        if (data["time to full"]) {
            timeToFullSeconds = parseTimeString(data["time to full"])
        }
        parseRateHistory(output)
        updateSmoothedTimeEstimates()
    }

    function getSmoothedTimeToEmpty() {
        var upowerEstimate = parseTimeString(data["time to empty"])

        // If UPower gives a reasonable estimate, use it with some smoothing
        if (upowerEstimate > 0 && upowerEstimate < 48 * 3600) { // Reasonable bounds: 48 hours
            return applyTimeSmoothing(upowerEstimate, 0)
        }

        // Fallback to calculated time using averaged power
        if (energyNowWh > 0 && powerHistory.length > 0) {
            var avgPower = calculateAveragePower()
            if (avgPower > 0.1) {
                var calculatedTime = (energyNowWh / avgPower) * 3600
                return applyTimeSmoothing(calculatedTime, 0)
            }
        }

        // No good estimate available
        return 0
    }

    function getSmoothedTimeToFull() {
        var upowerEstimate = parseTimeString(data["time to full"])

        if (upowerEstimate > 0 && upowerEstimate < 48 * 3600) {
            return applyTimeSmoothing(upowerEstimate, 1)
        }

        // Fallback to calculated time
        if (energyNowWh > 0 && energyFullWh > 0 && powerHistory.length > 0) {
            var avgPower = calculateAveragePower()
            var remainingEnergy = energyFullWh - energyNowWh
            if (avgPower > 0.1 && remainingEnergy > 0) {
                var calculatedTime = (remainingEnergy / avgPower) * 3600
                return applyTimeSmoothing(calculatedTime, 1)
            }
        }

        return 0
    }

    function calculateAveragePower() {
        if (powerHistory.length === 0) return 0

        // Use weighted average (more recent = higher weight)
        var total = 0
        var totalWeight = 0

        for (var i = 0; i < powerHistory.length; i++) {
            var weight = (i + 1) / powerHistory.length // Linear weights
            total += powerHistory[i] * weight
            totalWeight += weight
        }

        return total / totalWeight
    }

    function applyTimeSmoothing(newTime, estimateType) {
        // Keep history of time estimates for smoothing
        timeEstimateHistory.push({
            time: newTime,
            timestamp: Date.now(),
            type: estimateType
        })

        // Keep only recent estimates (last 60 seconds worth)
        var now = Date.now()
        timeEstimateHistory = timeEstimateHistory.filter(function(estimate) {
            return (now - estimate.timestamp) < 60000 && estimate.type === estimateType
        })

        if (timeEstimateHistory.length === 0) return newTime

        // Use median to avoid outliers
        var times = timeEstimateHistory.map(function(e) { return e.time }).sort()
        var median = times[Math.floor(times.length / 2)]

        return median
    }

    function updateSmoothedTimeEstimates() {
        var smoothedTimeToEmpty = getSmoothedTimeToEmpty()
        var smoothedTimeToFull = getSmoothedTimeToFull()

        // Update the properties with smoothed values
        if (smoothedTimeToEmpty > 0) {
            timeToEmptySeconds = smoothedTimeToEmpty
            lastStableTimeEstimate = smoothedTimeToEmpty
            lastStableTimeEstimateType = 0
        }

        if (smoothedTimeToFull > 0) {
            timeToFullSeconds = smoothedTimeToFull
            lastStableTimeEstimate = smoothedTimeToFull
            lastStableTimeEstimateType = 1
        }
    }

    function parseRateHistory(output) {
        if (!output || output.trim() === "") return

        var lines = output.trim().split('\n')
        var rates = []
        var lastRate = -1

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line.includes("History (rate):")) continue

            // Parse the rate history lines
            i++ // Skip header
            while (i < lines.length && lines[i].trim() !== "" && !lines[i].includes("History (")) {
                var historyLine = lines[i].trim()
                var parts = historyLine.split(/\s+/)
                if (parts.length >= 3) {
                    var rateStr = parts[2].replace(',', '.')
                    var rate = parseFloat(rateStr)
                    // Filter out 0 values during discharge, negative values, AND duplicates
                    if (rate > 0.1 && rate !== lastRate) {
                        rates.push(rate)
                        lastRate = rate
                    }
                }
                i++
            }
            break
        }
        if (rates.length > 0) {
            powerHistory = rates.slice(-maxHistorySize)
        }
    }

    function parseTimeString(timeStr) {
        // Parse time strings like "1.5 hours", "45 minutes", "19,1 minutes"
        if (!timeStr || timeStr === "0.0 seconds" || timeStr === "unknown") return 0

        // Replace comma with period for decimal numbers, then parse
        var normalizedStr = timeStr.replace(',', '.')

        var hoursMatch = normalizedStr.match(/([\d.]+)\s*hours?/)
        var minutesMatch = normalizedStr.match(/([\d.]+)\s*minutes?/)

        var totalSeconds = 0

        if (hoursMatch) {
            totalSeconds += parseFloat(hoursMatch[1]) * 3600
        }
        if (minutesMatch) {
            totalSeconds += parseFloat(minutesMatch[1]) * 60
        }

        return totalSeconds
    }

    // --- Action Functions ---
    function openPowerSettings() {
        // Open KDE Power Management settings
        Qt.openUrlExternally("systemsettings://power")
    }

    function toggleExpanded() {
        root.expanded = !root.expanded
    }

    // --- Formatting Functions ---
    function formatTime(seconds) {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        const remainingSeconds = Math.ceil(seconds % 60)

        if (hours > 0) {
            if (minutes > 0) {
                return hours + i18n("h") + " " + minutes + i18n("m")
            }
            return hours + i18n("h")
        }
        if (minutes > 0){
            return minutes + i18n("m")
        }
        return remainingSeconds + i18n("s");
    }

    function getBatteryText() {
        if (!batteryControl.hasBatteries) return i18n("No battery")
        const percent = batteryControl.percent
        if (batteryControl.pluggedIn) {
            if (percent === 100 || batteryControl.state === BatteryControlModel.FullyCharged) return percent + "% "+ i18n("Charged")
            if (batteryControl.state === BatteryControlModel.Charging) return percent + "% " + i18n("Charging")
            if (batteryControl.state === BatteryControlModel.Discharging) return percent + "% " + i18n("Plugged in")
            return percent + "% " + i18n("Not charging")
        }
        return percent + "% " + i18n("Discharging" )
    }

    // Use UPower's time estimates when available, fall back to calculation
    function getTimeText() {
        if (!batteryControl.hasBatteries) return i18n("No battery")
        if (batteryControl.pluggedIn && batteryControl.state === BatteryControlModel.FullyCharged) return "Charged"

        if (batteryControl.pluggedIn && batteryControl.state === BatteryControlModel.Charging) {
            if (timeToFullSeconds > 0) {
                return formatTime(timeToFullSeconds) + " " + i18n("until full")
            } else if (energyNowWh > 0) {
                // Fallback to calculation
                const remainingWh = energyFullWh - energyNowWh
                if (remainingWh <= 0) return i18n("Charged")
            }
            if (batteryControl.percent < 100) {
                return i18n("Charging")
            }
            return i18n("Charged")
        } else {
            if (timeToEmptySeconds > 0) {
                return formatTime(timeToEmptySeconds) + " " + i18n("left")
            } else if (energyNowWh > 0 && powerWatts > 0.1) {
                // Fallback to calculation
                const seconds = (energyNowWh / powerWatts) * 60
                return formatTime(seconds) + " " + i18n("left")
            }
            return i18n("Calculating")
        }
        return "?"
    }

    function getElapsedTimeText() {
        if (elapsedSeconds < 0) elapsedSeconds = 0
        const timeStr = formatTime(elapsedSeconds)
        return timeStr + (batteryControl.pluggedIn ? " " + i18n("since plugged") : " " + i18n("since unplugged"))
    }

    function getCapacityText() {
        if (energyFullDesignWh <= 0 || energyFullWh <= 0) return i18n("Health: N/A")

        const userDesignCapacity = useCustomDesignCapacity && customDesignCapacity > 0 ? customDesignCapacity : energyFullDesignWh
        const healthPercent = Math.round((energyFullWh / userDesignCapacity) * 100)

        return `Health: ${energyFullWh.toFixed(0)}/${userDesignCapacity.toFixed(0)} Wh (${healthPercent}%)`
    }

    function formatCurrent() {
        if (Math.abs(currentAmps) < 0.01) return "0.00 A"
        var sign = (batteryControl.pluggedIn && batteryControl.state === BatteryControlModel.Charging) ? "+" : "-"
        return sign + Math.abs(currentAmps).toFixed(2) + " A"
    }

    // --- UI Representations ---

    // Compact representation for system tray
    compactRepresentation: Item {
            Layout.preferredWidth: label.implicitWidth
            Layout.preferredHeight: label.implicitHeight

            PlasmaComponents.Label {
                id: label
                anchors.centerIn: parent
                text: batteryControl.hasBatteries ? getTimeText() : i18n("No battery")
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = !root.expanded
            }
    }

    // Full representation for desktop
    fullRepresentation: ColumnLayout {
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // Header with title
        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                source: "utilities-energy-monitor"
                width: Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
            }
            PlasmaComponents.Label {
                text: "Battery Statistics"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                font.bold: true
                Layout.fillWidth: true
            }
        }

        // Data rows
        PlasmaComponents.Label {
            text: "Status: " + getBatteryText()
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            visible: batteryControl.hasBatteries
        }

        PlasmaComponents.Label {
            text: "Remaining: " + getTimeText()
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            visible: batteryControl.hasBatteries && !(batteryControl.pluggedIn && batteryControl.percent == 100)
        }

        PlasmaComponents.Label {
            text: "Elapsed: " + getElapsedTimeText()
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            visible: batteryControl.hasBatteries
        }

        PlasmaComponents.Label {
            text: "Voltage: " + (voltageVolts > 0 ? voltageVolts.toFixed(1) + " V" : i18n("N/A"))
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            visible: batteryControl.hasBatteries
        }

        PlasmaComponents.Label {
            text: "Current: " + formatCurrent()
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            visible: batteryControl.hasBatteries
        }

        PlasmaComponents.Label {
            text: "Power: " + (powerWatts > 0 ? powerWatts.toFixed(1) + " W" : i18n("N/A"))
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            visible: batteryControl.hasBatteries
        }

        PlasmaComponents.Label {
            text: getCapacityText()
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            visible: batteryControl.hasBatteries
        }
        Item {
            // Bottom spacer
            Layout.preferredHeight: Kirigami.Units.smallSpacing
        }
    }

    // Tooltip for system tray hover
    toolTipMainText: getBatteryText()
    toolTipSubText: {
        var parts = []
        if (batteryControl.hasBatteries) {
            parts.push("Remaining: " + getTimeText())
            parts.push("Elapsed: " + getElapsedTimeText())
            if (voltageVolts > 0) parts.push("Voltage: " + voltageVolts.toFixed(1) + " V")
            if (powerWatts > 0) parts.push("Power: " + powerWatts.toFixed(1) + " W")
            if (energyFullWh > 0) parts.push(getCapacityText())
        }
        return parts.join("\n")
    }

    Component.onCompleted: {
        wasPluggedIn = batteryControl.pluggedIn
        restoreElapsedTime()
        updateBatteryData()
    }
}