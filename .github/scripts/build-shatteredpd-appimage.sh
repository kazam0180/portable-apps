#!/bin/bash
# Builds a Linux AppImage from the jpackage image using quick-sharun.
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

echo "==> [AppImage] Installing jpackage image to /usr/lib/shatteredpd"
rm -rf /usr/lib/shatteredpd
cp -a "/work/desktop/build/jpackage/Shattered Pixel Dungeon" /usr/lib/shatteredpd
chmod -R u+w /usr/lib/shatteredpd

echo "==> [AppImage] Fetching get-debloated-pkgs"
wget -qO /work/get-debloated-pkgs.sh \
	https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/get-debloated-pkgs.sh
chmod +x /work/get-debloated-pkgs.sh

echo "==> [AppImage] Fetching quick-sharun"
wget -qO /work/quick-sharun.sh \
	https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh
chmod +x /work/quick-sharun.sh

echo "==> [AppImage] Preparing bin wrapper"
mkdir -p /work/AppDir/bin
cat > /work/AppDir/bin/shatteredpd <<'EOF'
#!/bin/sh
APPIMAGE_APPDIR="${APPDIR:-$(cd "$(dirname "$0")"/.. && pwd)}"
export LD_LIBRARY_PATH="$APPIMAGE_APPDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$APPIMAGE_APPDIR/lib/shatteredpd/bin/Shattered Pixel Dungeon" "$@"
EOF
chmod +x /work/AppDir/bin/shatteredpd

echo "==> [AppImage] Determining version"
APP_VERSION=$(awk -F"'" '/appVersionName *=/{print $2; exit}' /work/build.gradle)
if [ -z "$APP_VERSION" ]; then
	echo "ERROR: Could not determine app version from build.gradle"
	exit 1
fi
echo "App version: $APP_VERSION"

./get-debloated-pkgs.sh --add-common --prefer-nano

echo "==> [AppImage] Deploying with quick-sharun"
cd /work
VERSION="$APP_VERSION" \
DESKTOP=/work/.github/assets/shatteredpd.desktop \
ICON=/work/desktop/src/main/assets/icons/icon_256.png \
APPDIR=/work/AppDir \
OUTPATH=/work \
OUTPUT_APPIMAGE=1 \
STRACE_BINARY='Shattered Pixel Dungeon' \
STRACE_TIME=10 \
DEPLOY_OPENGL=1 \
DEPLOY_PULSE=1 \
UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync" \
./quick-sharun.sh /usr/lib/shatteredpd

echo "==> [AppImage] Done"
ls -lah /work/*.AppImage
