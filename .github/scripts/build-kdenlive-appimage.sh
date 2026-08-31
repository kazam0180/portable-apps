#!/bin/bash
# Builds a Linux AppImage from the official Arch Linux kdenlive package using quick-sharun.
# Designed to run inside an archlinux container with the repo mounted at /work.
set -e

echo "==> [AppImage] Updating Arch container"
pacman -Syu --noconfirm --needed

echo "==> [AppImage] Installing dependencies"
pacman -S --noconfirm --needed \
	base-devel \
	wget \
	xorg-server-xvfb \
	strace \
	patchelf \
	tree

echo "==> [AppImage] Installing kdenlive and its dependencies from official repo"
pacman -S --noconfirm --needed kdenlive qt6ct kvantum lxqt-qtplugin

echo "==> [AppImage] Fetching get-debloated-pkgs"
wget -qO /work/get-debloated-pkgs.sh \
	https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/get-debloated-pkgs.sh
chmod +x /work/get-debloated-pkgs.sh

echo "==> [AppImage] Fetching quick-sharun"
wget -qO /work/quick-sharun.sh \
	https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh
chmod +x /work/quick-sharun.sh

echo "==> [AppImage] Preparing AppDir"
mkdir -p /work/AppDir/bin

echo "==> [AppImage] Creating wrapper script"
cat > /work/AppDir/bin/kdenlive <<'EOF'
#!/bin/sh
APPIMAGE_APPDIR="${APPDIR:-$(cd "$(dirname "$0")"/.. && pwd)}"
export LD_LIBRARY_PATH="$APPIMAGE_APPDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$APPIMAGE_APPDIR/bin/kdenlive" "$@"
EOF
chmod +x /work/AppDir/bin/kdenlive

echo "==> [AppImage] Determining version"
APP_VERSION=$(pacman -Qi kdenlive | awk -F': ' '/^Version/{print $2}' | cut -d'-' -f1)
if [ -z "$APP_VERSION" ]; then
	echo "ERROR: Could not determine kdenlive version"
	exit 1
fi
echo "App version: $APP_VERSION"

./get-debloated-pkgs.sh --add-common --prefer-nano

echo "==> [AppImage] Deploying with quick-sharun"
cd /work
VERSION="$APP_VERSION" \
DESKTOP=/work/.github/assets/kdenlive.desktop \
ICON=/usr/share/icons/hicolor/scalable/apps/kdenlive.svg \
APPDIR=/work/AppDir \
OUTPATH=/work \
OUTPUT_APPIMAGE=1 \
STRACE_BINARY='kdenlive' \
STRACE_TIME=10 \
DEPLOY_OPENGL=1 \
DEPLOY_PULSE=1 \
UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync" \
./quick-sharun.sh /usr/bin/kdenlive /usr/bin/kdenlive_render /usr/bin/melt

echo "==> [AppImage] Done"
ls -lah /work/*.AppImage
