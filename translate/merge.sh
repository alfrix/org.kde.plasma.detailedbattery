#!/bin/bash
# Version: 31 - Minimal Compliant Header with Generated Date

# This script extracts, merges, and cleans translation files for KDE plasmoids.

DIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd`
METADATA_FILE="$DIR/../metadata.json"
packageRoot=".." # Root of translatable sources

# --- Simple Console Output Functions ---
function echoError() { echo "ERROR: [translate/merge] $1" >&2; exit 1; }
function echoWarning() { echo "WARNING: [translate/merge] $1" >&2; }
function echoMsg() { echo "[translate/merge] $1"; }

#---
# Read properties from metadata.json using jq
if [ -z "$(which jq)" ]; then
	echoError "jq command not found. Need to install jq."
fi

# Read necessary values from metadata.json
plasmoidName=`jq -r '.KPlugin.Id' "$METADATA_FILE"`
widgetName="${plasmoidName##*.}" # Strip namespace

if [ -z "$plasmoidName" ] || [ "$plasmoidName" == "null" ]; then
	echoError "Couldn't read plasmoidName from ${METADATA_FILE}. Check 'KPlugin.Id'."
fi

if [ -z "$(which xgettext)" ]; then
	echoError "xgettext command not found. Need to install gettext."
fi

# --- Date Generation ---
# Generate the POT date string in the required format (e.g., 2025-10-07 11:47+0100)
# We use date -u to get GMT/UTC, which is standard for POT files, and append +0000.
CURRENT_DATE_TIME=$(date -u +%Y-%m-%d\ %H:%M:%S+0000)

# --- Define Minimal Header ---
MINIMAL_HEADER='msgid ""
msgstr ""
"Project-Id-Version: '"${widgetName}"'\\n"
"POT-Creation-Date: '"${CURRENT_DATE_TIME}"'\\n"
"Content-Type: text/plain; charset=UTF-8\\n"

'
# Note: The final blank line in MINIMAL_HEADER is essential for separation.

#---
echoMsg "Extracting messages"
potArgs="--from-code=UTF-8 --width=200 --add-location=file"

# Find all translatable source files
find "${packageRoot}" -name '*.cpp' -o -name '*.h' -o -name '*.c' -o -name '*.qml' -o -name '*.js' | sort > "${DIR}/infiles.list"
xgettext \
	${potArgs} \
	-d "${widgetName}" \
	--files-from="${DIR}/infiles.list" \
	-C -kde \
	-ci18n \
	-ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
	-kki18n:1 -kki18nc:1c,2 -kki18np:1,2 -kki18ncp:1c,2,3 \
	-kxi18n:1 -kxi18nc:1c,2 -kxi18np:1,2 -kxi18ncp:1c,2,3 \
	-kkxi18n:1 -kkxi18nc:1c,2 -kkxi18np:1,2 -kkxi18ncp:1c,2,3 \
	-kI18N_NOOP:1 -kI18NC_NOOP:1c,2 \
	-kI18N_NOOP2:1c,2 -kI18N_NOOP2_NOSTRIP:1c,2 \
	-ktr2i18n:1 -ktr2xi18n:1 \
	-kN_:1 \
	-kaliasLocale \
	-D "${packageRoot}" \
	-D "${DIR}" \
	-o "template.pot.new" \
	|| echoError "error while calling xgettext. aborting."

# --- MINIMAL METADATA CLEANUP & FORMATTING ---

# 1. Remove all comments/flags, including references.
sed -i '/^#/d' "template.pot.new"

# 2. Delete the entire old header block (all lines up to the first actual msgid).
# Find line number of the second occurrence of msgid (the first *actual* string)
# Note: We must search for "msgid " to avoid matching header lines like "Report-Msgid-Bugs-To".
FIRST_MSGID_LINE=$(grep -n 'msgid "' "template.pot.new" | head -n 2 | tail -n 1 | cut -d: -f1)

if [ -z "$FIRST_MSGID_LINE" ]; then
    # If no translatable strings, delete all content.
    sed -i '1,$d' "template.pot.new"
else
    # Delete the old header (from line 1 up to the line *before* the first actual msgid)
    HEADER_END_LINE=$(expr $FIRST_MSGID_LINE - 2)
    if [ "$HEADER_END_LINE" -gt 0 ]; then
        sed -i "1,${HEADER_END_LINE}d" "template.pot.new"
    fi
fi

# 3. Prepend the new, perfect minimal header.
echo -e "${MINIMAL_HEADER}$(cat "template.pot.new")" > "template.pot.new.temp"
mv "template.pot.new.temp" "template.pot.new"

# 4. Normalize blank lines: ensures one blank line separates each entry (run again just in case).
sed -i '/^$/N;/^\n$/D' "template.pot.new"


if [ -f "template.pot" ]; then
	# --- POT file comparison logic (updated for generated date) ---
    # To compare correctly, we temporarily replace the new POT-Creation-Date with the old one.
	newPotDate=`grep "POT-Creation-Date:" template.pot.new | sed 's/.\{3\}$//'`
	oldPotDate=`grep "POT-Creation-Date:" template.pot | sed 's/.\{3\}$//'`
	# Replace new date with old date in new file for comparison
	sed -i 's/'"${newPotDate}"'/'"${oldPotDate}"'/' "template.pot.new"

	changes=`diff "template.pot" "template.pot.new"`

	if [ ! -z "$changes" ]; then
        # If there are changes, restore the new date before moving
		sed -i 's/'"${oldPotDate}"'/'"${newPotDate}"'/' "template.pot.new"
		mv "template.pot.new" "template.pot"
		# Print difference feedback
		echo ""
		echo "Added Keys:"
		echo "$changes" | grep "> msgid" | cut -c 9- | sort
		echo ""
		echo "Removed Keys:"
		echo "$changes" | grep "< msgid" | cut -c 9- | sort
		echo ""
	else
		rm "template.pot.new"
	fi
else
	mv "template.pot.new" "template.pot"
fi

# Status calculation and table generation (unchanged)
if [ -f "template.pot" ] && [ -s "template.pot" ]; then
    potMessageCount=`expr $(grep -Pzo 'msgstr ""\n(\n|$)' "template.pot" | grep -c 'msgstr ""')`
else
    potMessageCount=0
fi

echo "|  Locale  |  Lines  | % Done|" > "./Status.md"
echo "|----------|---------|-------|" >> "./Status.md"
entryFormat="| %-8s | %7s | %5s |"
templateLine=`perl -e "printf(\"$entryFormat\", \"Template\", \"${potMessageCount}\", \"\")"`
echo "$templateLine" >> "./Status.md"

rm "${DIR}/infiles.list"
echoMsg "Done extracting messages"

#---
echoMsg "Merging messages"
catalogs=`find . -name '*.po' | sort`
for cat in $catalogs; do
	echoMsg "Updating ${cat}"
	catLocale=`basename ${cat%.*}`

	widthArg=""
	catUsesGenerator=`grep "X-Generator:" "$cat"`
	if [ -z "$catUsesGenerator" ]; then
		widthArg="--width=400"
	fi

	compendiumArg=""
	if [ ! -z "$COMPENDIUM_DIR" ]; then
		langCode=`basename "${cat%.*}"`
		compendiumPath=`realpath "$COMPENDIUM_DIR/compendium-${langCode}.po"`
		if [ -f "$compendiumPath" ]; then
			echo "compendiumPath=$compendiumPath"
			compendiumArg="--compendium=$compendiumPath"
		fi
	fi

	cp "$cat" "$cat.new"

	msgmerge \
		${widthArg} \
		--add-location=file \
		--no-fuzzy-matching \
		${compendiumArg} \
		-o "$cat.new" \
		"$cat.new" "${DIR}/template.pot"

	# Cleanup PO files: Remove ALL comments and non-essential fields
	sed -i '/^#/d' "$cat.new"
	sed -i '/^"PO-Revision-Date:/d' "$cat.new"
	sed -i '/^"Last-Translator:/d' "$cat.new"
	sed -i '/^"Language-Team:/d' "$cat.new"
	sed -i '/^"Report-Msgid-Bugs-To:/d' "$cat.new"

	# Fix formatting: Ensure one blank line separation
	sed -i '/^$/N;/^\n$/D' "$cat.new"

	poEmptyMessageCount=`expr $(grep -Pzo 'msgstr ""\n(\n|$)' "$cat.new" | grep -c 'msgstr ""')`
	poMessagesDoneCount=`expr $potMessageCount - $poEmptyMessageCount`
	poCompletion=`perl -e "printf(\"%d\", $poMessagesDoneCount * 100 / $potMessageCount)"`
	poLine=`perl -e "printf(\"$entryFormat\", \"$catLocale\", \"${poMessagesDoneCount}/${potMessageCount}\", \"${poCompletion}%\")"`
	echo "$poLine" >> "./Status.md"

	mv "$cat.new" "$cat"
done
echoMsg "Done merging messages"

#---
echoMsg "Updating translate/ReadMe.md"

# Use the plasmoidName read from JSON
sed -i -E 's`share\/plasma\/plasmoids\/(.+)\/translate`share/plasma/plasmoids/'"${plasmoidName}"'/translate`' ./ReadMe.md

sed -i '/^|/ d' ./ReadMe.md # Remove status table from ReadMe
cat ./Status.md >> ./ReadMe.md
rm ./Status.md

echoMsg "Done merge script"
