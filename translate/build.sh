#!/bin/bash
# Version: 9 - Fixed realpath and mv errors

# This script will convert the *.po files to *.mo files, rebuilding the package/contents/locale folder.
# Eg: contents/locale/fr_CA/LC_MESSAGES/plasma_applet_org.kde.plasma.detailedbattery.mo

DIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd`
METADATA_FILE="$DIR/../metadata.json"
packageRoot="${DIR}/.." # Root of translatable sources
plasmoidDirName=$(basename "$(realpath "$packageRoot")")

# --- Simple Console Output Functions (Minimal) ---
function echoMsg() { echo "[translate/build] $1"; }
function echoError() { echo "[translate/build] ERROR: $1" >&2; exit 1; }

#---
# Read properties from metadata.json using jq
if [ -z "$(which jq)" ]; then
	echoError "jq command not found. Need to install jq. Please run 'sudo apt install jq'"
fi

# Read necessary values from metadata.json
plasmoidName=`jq -r '.KPlugin.Id' "$METADATA_FILE"`
projectName="plasma_applet_${plasmoidName}" # project name

if [ -z "$plasmoidName" ] || [ "$plasmoidName" == "null" ]; then
	echoError "Couldn't read plasmoidName from ${METADATA_FILE}. Check 'KPlugin.Id'."
fi

if [ -z "$(which msgfmt)" ]; then
	echoError "msgfmt command not found. Need to install gettext. Please run 'sudo apt install gettext'"
fi

#---
echoMsg "Compiling messages"

# The original relativePath function is removed as it was complex and unnecessary.

# Find all translation catalogs (*.po files)
catalogs=`find . -name '*.po' | sort`
for cat in $catalogs; do
	catLocale=`basename ${cat%.*}`
	moFilename="${catLocale}.mo"

	# 1. CONSTRUCT INSTALLATION PATHS (Relative to the plasmoid root)
	# The destination directory: contents/locale/[lang]/LC_MESSAGES/
	installDir="${packageRoot}/contents/locale/${catLocale}/LC_MESSAGES"

    # The final destination MO file path
	installPathFinal="${installDir}/${projectName}.mo"

    # The path for display purposes (relative to the current directory)
    relativeInstallPath="..${installPathFinal#$packageRoot}"

	echoMsg "Converting '${cat}' => '${relativeInstallPath}'"

	# 2. Compile the .po file into a temporary .mo file in the current directory
	msgfmt -o "${moFilename}" "${cat}"

	# 3. Ensure the destination directory exists (including parent folders)
	mkdir -p "$installDir"

	# 4. Move the compiled .mo file to the final destination
    # The temporary moFilename is in the current directory, and the destination is the full path.
	mv "${moFilename}" "${installPathFinal}"
done

echoMsg "Done building messages"

#---
# Plasma Restart Logic
#---
if [ "$1" = "--restartplasma" ]; then
	echoMsg "Restarting plasmashell"
	killall plasmashell
	kstart5 plasmashell
	echoMsg "Done restarting plasmashell"
else
	echoMsg "(re)install the plasmoid and restart plasmashell to test translations."
fi
