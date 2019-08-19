#!/usr/bin/env bash

set -e

if [ ! -f "$(pwd)/private.pem" ]; then
  echo "You must have 'private.pem' configured to continue..."
  exit 1
fi

cd "sparkle-cli-utils"
make
cd ".."

rm -rf release

APP_NAME="Mr. Puppet Hub"
AWS_PATH="puppet-hub"

# Build .app and .dmg
bundle exec fastlane build_mac

rm -f release/*.plist release/*.log release/*.dSYM.zip

# Look up app version info
CFBundleShortVersionString="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "./release/$APP_NAME.app/Contents/Info.plist")"
CFBundleVersion="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "./release/$APP_NAME.app/Contents/Info.plist")"

AWS_RELEASE_PATH="$AWS_PATH/$CFBundleShortVersionString/$CFBundleVersion"
PUBLIC_DMG_URL="https://thinko-artifacts.accelerator.net/$AWS_RELEASE_PATH/$APP_NAME.dmg"
PUBLIC_APPCAST_URL="https://thinko-artifacts.accelerator.net/$AWS_RELEASE_PATH/appcast.xml"

# Prepare appcast.xml
APP_PATH="$(pwd)/release/$APP_NAME.app"
DMG_PATH="$(pwd)/release/$APP_NAME.dmg"

PUB_KEY="4BteBsDajLSOJrHhOI4zaLHoBT5OQ/FVyiKcyPGgCtM="
PRV_KEY="$(cat private.pem)"

APP_SIGNATURE="$(./sparkle-cli-utils/build/Release/generate_signature "$DMG_PATH" "$PUB_KEY" "$PRV_KEY")"

./sparkle-cli-utils/build/Release/generate_appcast "$APP_PATH" "$PUBLIC_DMG_URL" "$APP_SIGNATURE"

bundle exec fastlane package_zip

# Upload .zip, .dmg and appcast.xml
aws s3 cp "release/$APP_NAME.app.zip" "s3://thinko-artifacts/$AWS_RELEASE_PATH/"
aws s3 cp "release/$APP_NAME.dmg" "s3://thinko-artifacts/$AWS_RELEASE_PATH/"
aws s3 cp "release/appcast.xml" "s3://thinko-artifacts/$AWS_RELEASE_PATH/"

echo ""
echo "  Assets uploaded to CDN"
echo "  ======================"
echo ""
echo "  Update 'APPCAST_URL' env var in Heroku with $PUBLIC_APPCAST_URL"
echo ""
