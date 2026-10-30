#!/bin/zsh
# Boots a simulator, adds generated photos and grants full photo access to the app.
# Each of the last [months] months (default 12) gets a small photo and a bigger one a minute older.
# It only adds media; run it again when the tests have used up the seeded photos.
# Usage: [BUNDLE_ID_PREFIX=<prefix>] scripts/seed-simulator.sh <simulator-udid> [months] [scratch-dir]
# BUNDLE_ID_PREFIX must match the build setting (default com.example, as in Config/Base.xcconfig).
set -euo pipefail

udid=${1:?usage: [BUNDLE_ID_PREFIX=<prefix>] seed-simulator.sh <simulator-udid> [months] [scratch-dir]}
months=${2:-12}
scratch=${3:-/tmp/photo-cleanup-seed}
bundle_id=${BUNDLE_ID_PREFIX:-com.example}.PhotoCleanup
script_dir=${0:A:h}

xcrun simctl bootstatus "$udid" -b >/dev/null
mkdir -p "$scratch"
photos=("${(@f)$(swift "$script_dir/make-seed-photos.swift" "$scratch" "$months")}")
xcrun simctl addmedia "$udid" "${photos[@]}"
xcrun simctl privacy "$udid" grant photos "$bundle_id"
echo "Seeded ${#photos[@]} photos into $udid and granted photo access to $bundle_id"
