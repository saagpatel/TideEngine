#!/bin/bash
set -euo pipefail

# Run on the dispatcher's Mac with Xcode and the named simulator installed.
# SHOT_WAIT defaults to 4 seconds; SHOT_WAIT_1, _2, _3 override individual shots.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
DERIVED=${DERIVED:-.build/shots}
OUTPUT="$ROOT/screenshots/appstore"
device_names=("iPhone 18 Pro Max")
device_slugs=("iphone-18-pro-max")
device_widths=(1320)
device_heights=(2868)
device_ids=()
device_states=()
booted_ids=()
overridden_ids=()

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
    local result=$? id
    trap - EXIT
    set +e
    # Bash 3.2 treats empty-array expansion as unbound under nounset.
    set +u
    for id in "${overridden_ids[@]}"; do
        if ! xcrun simctl status_bar "$id" clear; then
            printf 'ERROR: could not clear status bar for %s\n' "$id" >&2
            result=1
        fi
    done
    for id in "${booted_ids[@]}"; do
        if ! xcrun simctl shutdown "$id"; then
            printf 'ERROR: could not shut down task-booted device %s\n' "$id" >&2
            result=1
        fi
    done
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Resolve all devices before building. Ambiguous names require operator cleanup.
devices_json=$(xcrun simctl list devices available -j)
for name in "${device_names[@]}"; do
    selected=$(printf '%s' "$devices_json" | python3 -c '
import json, sys
name = sys.argv[1]
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group
           if d.get("isAvailable", False) and d["name"] == name]
if len(devices) != 1:
    sys.exit(f"ERROR: expected one available simulator named {name!r}; found {len(devices)}. Create/install the required device/runtime or resolve duplicate names in Xcode.")
device = devices[0]
state = device["state"]
if state not in ("Booted", "Shutdown"):
    sys.exit(f"ERROR: {name} is {state}; wait for it to settle before capture.")
print(device["udid"] + "\t" + state)
' "$name")
    IFS=$'\t' read -r id state <<< "$selected"
    device_ids+=("$id")
    device_states+=("$state")
done

xcodebuild build -project TideEngine.xcodeproj -scheme TideEngine \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO

apps=()
for candidate in "$DERIVED"/Build/Products/Debug-iphonesimulator/*.app; do
    if [[ -d "$candidate" ]]; then apps+=("$candidate"); fi
done
[[ ${#apps[@]} -eq 1 ]] || fail "Expected exactly one built .app in $DERIVED/Build/Products/Debug-iphonesimulator."
app=${apps[0]}
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
[[ -n "$bundle_id" ]] || fail "Built app Info.plist has no bundle identifier."

for index in "${!device_names[@]}"; do
    id=${device_ids[$index]}
    if [[ ${device_states[$index]} == Shutdown ]]; then
        booted_ids+=("$id")
        xcrun simctl boot "$id"
    fi
    xcrun simctl bootstatus "$id" -b
    overridden_ids+=("$id")
    xcrun simctl status_bar "$id" override --time 9:41 --dataNetwork wifi \
        --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
    xcrun simctl install "$id" "$app"
    xcrun simctl ui "$id" appearance dark
    directory="$OUTPUT/${device_slugs[$index]}"
    mkdir -p "$directory"

    # Make this app the previous foreground app to clear the cross-app back link.
    SIMCTL_CHILD_TZ=UTC xcrun simctl launch "$id" "$bundle_id" \
        -AppStoreScreenshot 1 -AppleLanguages '(en)' -AppleLocale en_US
    sleep 2
    xcrun simctl terminate "$id" "$bundle_id" >/dev/null 2>&1 || true

    # Widgets are deliberately excluded: simctl launch cannot arrange the Home Screen.
    for shot in 1 2 3; do
        wait_variable="SHOT_WAIT_$shot"
        wait_seconds=${!wait_variable:-${SHOT_WAIT:-4}}
        [[ $wait_seconds =~ ^[0-9]+([.][0-9]+)?$ ]] || fail "$wait_variable/SHOT_WAIT must be non-negative seconds."
        # simctl returns nonzero when the app is not already running.
        xcrun simctl terminate "$id" "$bundle_id" >/dev/null 2>&1 || true
        SIMCTL_CHILD_TZ=UTC xcrun simctl launch "$id" "$bundle_id" \
            -AppStoreScreenshot "$shot" -AppleLanguages '(en)' -AppleLocale en_US
        sleep "$wait_seconds"
        printf -v filename '%s/%02d.png' "$directory" "$shot"
        xcrun simctl io "$id" screenshot "$filename"
        dimensions=$(sips -g pixelWidth -g pixelHeight "$filename")
        width=$(printf '%s\n' "$dimensions" | awk '$1 == "pixelWidth:" { print $2 }')
        height=$(printf '%s\n' "$dimensions" | awk '$1 == "pixelHeight:" { print $2 }')
        [[ $width == "${device_widths[$index]}" && $height == "${device_heights[$index]}" ]] \
            || fail "$filename is ${width:-unknown}x${height:-unknown}; expected ${device_widths[$index]}x${device_heights[$index]}."
        printf 'Captured %s (%sx%s)\n' "$filename" "$width" "$height"
    done
done
