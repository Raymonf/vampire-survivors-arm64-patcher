#!/bin/bash
# Vampire Survivors arm64 Patcher
# https://github.com/Raymonf/VS-arm64-patcher

set -e

###############

FORCE_REINSTALL_ELECTRON=false
FORCE_REINSTALL_GREENWORKS=false
FORCE_REINSTALL_LIBSTEAM=false
ELECTRON_VERSION="v19.0.13" # you probably don't want to change this from v19.x if you don't know what you're doing!
ELECTRON_TYPE="electron-$ELECTRON_VERSION-darwin-arm64"
APP_DIR="$HOME/Library/Application Support/Steam/steamapps/common/Vampire Survivors/Vampire_Survivors.app"
CLEANUP=true
RESIGN_ENTIRE_GAME=false

##############

GREENWORKS_FILE_NAME="greenworks-osxarm64.node"
GREENWORKS_URL="https://github.com/Raymonf/VS-arm64-patcher/releases/download/license2/greenworks-osxarm64.node"
GREENWORKS_SHA256_HASH="0c62810b821c8894a7a09920e32a0d34dceb904dd254e2e35f9ed966d38523ba"

LIBSTEAM_ZIP_NAME="steam_macos.zip"
LIBSTEAM_ZIP_URL="https://github.com/Raymonf/VS-arm64-patcher/releases/download/license/steam_macos.zip"
LIBSTEAM_SHA256_HASH="1614a0e71ed05d24a8d66c6e45a934834664dc6285dc8717378bfa430ad9fc3d"
LIBAPPTICKET_SHA256_HASH="46212b89599d6a32f18d5d8a760d19be3c10170dcb6ec783b8b5b69376bef6ea"

##############

# make sure we're working with the macOS version of VS
BINARY_DIR="Contents/MacOS/VampireSurvivors"
NATIVE_MODULE_DIR="Contents/Resources/app/.webpack/main/native_modules"

red_echo() {
	echo -e "\033[0;31m$1\033[0m"
}

green_echo() {
	echo -e "\033[1;32m$1\033[0m"
}

yellow_echo() {
	echo -e "\033[1;33m$1\033[0m"
}

blue_echo() {
	echo -e "\033[1;34m$1\033[0m"
}

check_sha256() {
    shasum -a 256 -c <<<"$2  $1"
}

# in case it's installed to somewhere else
ensure_app_dir() {
	while [ ! -d "$APP_DIR" ]; do
		read -p "Game couldn't be found. Drag the app here and press [Enter]: " APP_DIR
	done

	if [ ! -f "$APP_DIR/$BINARY_DIR" ]; then
		red_echo " ! Couldn't find '$APP_DIR/$BINARY_DIR', goodbye!"; exit 1
	fi

	# we have the binary at least, good enough /shrug
	green_echo "Using game path: $APP_DIR"
}

install_electron() {
	blue_echo "Setting up Electron..."

	# grab electron if we don't have it
	ELECTRON_ZIPNAME="$ELECTRON_TYPE.zip"
	ELECTRON_BASE_DIR="VS_$ELECTRON_TYPE"
	if [ ! -f "$ELECTRON_ZIPNAME" ]; then
		ELECTRON_URL="https://github.com/electron/electron/releases/download/$ELECTRON_VERSION/electron-$ELECTRON_VERSION-darwin-arm64.zip"
		yellow_echo " * Downloading '$ELECTRON_ZIPNAME'..."
		curl -LO "$ELECTRON_URL" -o "$ELECTRON_ZIPNAME"
	fi

	# extract the electron zip if it's not already in its own folder
	if [[ ! -d "$ELECTRON_BASE_DIR/Electron.app/Contents/Frameworks/Electron Framework.framework" || ! -f "$ELECTRON_TYPE/Electron.app/Contents/MacOS/Electron" ]]; then
		mkdir -p "$ELECTRON_BASE_DIR"
		yellow_echo " * Unzipping Electron to '$ELECTRON_BASE_DIR'..."
		unzip -q -o "$ELECTRON_ZIPNAME" -d "$ELECTRON_BASE_DIR"
	fi

	# replace main binary
	yellow_echo " * Moving arm64 Electron wrapper binary..."
	cp "$ELECTRON_BASE_DIR/Electron.app/Contents/MacOS/Electron" "$APP_DIR/$BINARY_DIR"

	# update frameworks
	FRAMEWORKS_ARM64_DIR="$ELECTRON_BASE_DIR/Electron.app/Contents/Frameworks"
	FRAMEWORKS_GAME_DIR="$APP_DIR/Contents/Frameworks"
	if [ -d "$FRAMEWORKS_GAME_DIR" ]; then
		yellow_echo " * Deleting old Frameworks folder at '$FRAMEWORKS_GAME_DIR'..."
		rm -R "$FRAMEWORKS_GAME_DIR"
	fi
	yellow_echo " * Moving arm64 Frameworks folder..."
	cp -R "$FRAMEWORKS_ARM64_DIR" "$FRAMEWORKS_GAME_DIR"

	if [ "$CLEANUP" = true ]; then
		yellow_echo " * Cleaning up Electron..."
		rm -R "$ELECTRON_BASE_DIR"
		rm "$ELECTRON_ZIPNAME"
	fi
}

install_greenworks() {
	blue_echo "Setting up Steam libraries..."
	curl -LO "$GREENWORKS_URL" -o "$GREENWORKS_FILE_NAME"
	if ! check_sha256 "$GREENWORKS_FILE_NAME" "$GREENWORKS_SHA256_HASH"; then
		red_echo " ! Downloaded file '$GREENWORKS_FILE_NAME' did not match the expected hash"; exit 1
	fi
	cp "$GREENWORKS_FILE_NAME" "$APP_DIR/$NATIVE_MODULE_DIR/greenworks-osxarm64.node"
	rm "$GREENWORKS_FILE_NAME"
	yellow_echo " * Attempting to resign Greenworks..."
	codesign --force --sign - "$APP_DIR/$NATIVE_MODULE_DIR/greenworks-osxarm64.node"
}

install_libsteam() {
	blue_echo "Setting up Steam libraries..."

	# grab libsteam_api.dylib if we don't have it, or if the hash doesn't match
	LIBSTEAM_BASE_DIR="VS_libsteam"
	LIBSTEAM_ARM64_PATH="$LIBSTEAM_BASE_DIR/libsteam_api.dylib"
	LIBAPPTICKET_ARM64_PATH="$LIBSTEAM_BASE_DIR/libsdkencryptedappticket.dylib"
	if [ ! -d "$LIBSTEAM_BASE_DIR" || ! -f "$LIBSTEAM_ARM64_PATH" || ! -f "$LIBAPPTICKET_ARM64_PATH" || ! check_sha256 "$LIBSTEAM_ARM64_PATH" "$LIBSTEAM_SHA256_HASH" || ! check_sha256 "$LIBAPPTICKET_ARM64_PATH" "$LIBAPPTICKET_SHA256_HASH" ]; then
		yellow_echo " * Downloading Steam libraries..."
		mkdir -p "$LIBSTEAM_BASE_DIR"
		curl -L -o "$LIBSTEAM_BASE_DIR/$LIBSTEAM_ZIP_NAME" "$LIBSTEAM_ZIP_URL"
		unzip -q -o "$LIBSTEAM_BASE_DIR/$LIBSTEAM_ZIP_NAME" -d "$LIBSTEAM_BASE_DIR"
		rm "$LIBSTEAM_BASE_DIR/$LIBSTEAM_ZIP_NAME"
	fi

	if ! check_sha256 "$LIBSTEAM_ARM64_PATH" "$LIBSTEAM_SHA256_HASH" || ! check_sha256 "$LIBAPPTICKET_ARM64_PATH" "$LIBAPPTICKET_SHA256_HASH"; then
		red_echo " ! Extracted Steam libraries did not match the expected hashes"; exit 1
	fi

	# now it should be there, time to replace them
	yellow_echo " * Replacing Steam libraries..."
	cp "$LIBSTEAM_ARM64_PATH" "$APP_DIR/$NATIVE_MODULE_DIR/libsteam_api.dylib"
	cp "$LIBAPPTICKET_ARM64_PATH" "$APP_DIR/$NATIVE_MODULE_DIR/libsdkencryptedappticket.dylib"

	yellow_echo " * Attempting to resign Steam libraries..."
	codesign --force --sign - "$APP_DIR/$NATIVE_MODULE_DIR/libsteam_api.dylib"
	codesign --force --sign - "$APP_DIR/$NATIVE_MODULE_DIR/libsdkencryptedappticket.dylib"

	if [ "$CLEANUP" = true ]; then
		yellow_echo " * Cleaning up Steam libraries..."
		rm -R "$LIBSTEAM_BASE_DIR"
	fi
}

patch_game() {
	blue_echo "Patching game to detect and use arm64 Greenworks..."
	# ugly hack ugly hack ugly hack ugly hack ugly hack ugly hack
	sed -i '' "s/','x64',/','arm64',/g" "$APP_DIR/Contents/Resources/app/.webpack/main/index.js"
	sed -i '' 's/greenworks-osx64\.node/greenworks-\osxarm64.node/g' "$APP_DIR/Contents/Resources/app/.webpack/main/index.js"
}

resign_game() {
	blue_echo "Resigning game..."
	codesign --force --deep --sign - "$APP_DIR"
}

magic() {
	green_echo "[Vampire Survivors arm64 Patcher]"

	ensure_app_dir

	if [[ "$FORCE_REINSTALL_ELECTRON" = true || ! $(file -b "$APP_DIR/$BINARY_DIR") =~ "arm64" ]]; then
		install_electron
	fi

	if [[ "$FORCE_REINSTALL_GREENWORKS" = true || ! -f "$APP_DIR/$NATIVE_MODULE_DIR/greenworks-osxarm64.node" ]]; then
		install_greenworks
	fi

	if [[ "$FORCE_REINSTALL_LIBSTEAM" = true || ! $(file -b "$APP_DIR/$NATIVE_MODULE_DIR/libsteam_api.dylib") =~ "arm64" || ! $(file -b "$APP_DIR/$NATIVE_MODULE_DIR/libsdkencryptedappticket.dylib") =~ "arm64" ]]; then
		install_libsteam
	fi

	# apply arm64 patches to the game's code
	patch_game

	if [ "$RESIGN_ENTIRE_GAME" = true ]; then
		resign_game
	fi

	green_echo "All done! Be sure to re-run this script whenever the game updates."
}

magic