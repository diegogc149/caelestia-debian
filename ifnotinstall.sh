#!/bin/bash

sudo tee /etc/apt/sources.list.d/debian-experimental.sources <<EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: experimental
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

sudo apt update
sudo apt install qt6-base-dev qt6-base-dev-tools qt6-base-private-dev \
  qt6-declarative-dev qt6-declarative-dev-tools \
  qt6-declarative-private-dev qml6-module-qtquick-effects \
  qt6-shadertools-dev \
  qt6-svg-dev \
  qt6-wayland-dev qt6-wayland-private-dev \
  qml6-module-qt5compat-graphicaleffects \
  qt6-image-formats-plugins qt6-image-formats-plugin-pdf

bash ./build-kf6-qt611.sh

# Define directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$HOME/caelestia-build"
mkdir -p "$WORK_DIR"

echo "=== Caelestia Installer for Debian Trixie (or maybe sid, idk) ==="
echo "Working directory: $WORK_DIR"
echo ""

if [ "$EUID" -eq 0 ]; then
  echo "ERROR: Please do not run this script as root. Run it as your normal user."
  echo "It will ask for sudo password when necessary."

fi

if ! command -v sudo &>/dev/null; then
  echo "ERROR: sudo is not installed. Please install sudo and configure your user before running this script."
  exit 1
fi

# 3.5 Install papirus-folders manually
echo "=== Installing papirus-folders ==="
if ! command -v papirus-folders &>/dev/null; then
  sudo curl -sL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders -o /usr/local/bin/papirus-folders
  sudo chmod +x /usr/local/bin/papirus-folders
fi

# 4. Build and Install libcava from source
echo "=== Building libcava from source ==="
if [ ! -d "$WORK_DIR/libcava-src" ]; then
  git clone https://github.com/LukashonakV/cava.git "$WORK_DIR/libcava-src"
fi
cd "$WORK_DIR/libcava-src"
rm -rf build
meson setup build --prefix=/usr/local --buildtype=release
meson compile -C build
sudo meson install -C build

# 5. Build and Install Quickshell from source
echo "=== Building Quickshell from source ==="
if [ ! -d "$WORK_DIR/quickshell" ]; then
  git clone --recursive https://github.com/outfoxxed/quickshell.git "$WORK_DIR/quickshell"
fi
cd "$WORK_DIR/quickshell"
rm -rf build
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DVENDOR_CPPTRACE=ON -DINSTALL_QMLDIR=/usr/lib/x86_64-linux-gnu/qt6/qml
cmake --build build -j$(nproc)
sudo cmake --install build

#5.1 Build and Install qt6-m3shapes from source
echo "=== Building qt6-m3shapes-git from source ==="
if [ ! -d "$WORK_DIR/m3shapes" ]; then
  git clone https://github.com/soramanew/m3shapes.git "$WORK_DIR/m3shapes"
fi
cd "$WORK_DIR/m3shapes"
rm -rf build
mkdir build && cd build
cmake .. -G Ninja -DCMAKE_CXX_COMPILER=clang++
ninja
sudo ninja install
sudo ln -s /usr/local/lib/qt6/qml/M3Shapes /usr/lib/x86_64-linux-gnu/qt6/qml/M3Shapes

# 7. Install Caelestia CLI (with Debian Patches)
echo "=== Installing Caelestia CLI  ==="
if [ ! -d "$WORK_DIR/caelestia-cli-git" ]; then
  git clone https://github.com/caelestia-dots/cli.git "$WORK_DIR/caelestia-cli-git"
fi
cd "$WORK_DIR/caelestia-cli-git"
#git reset --hard
#git apply "$SCRIPT_DIR/patches/caelestia-cli.patch"
#git apply "$SCRIPT_DIR/patches/caelestia-cli-recorder.patch"
pip install --break-system-packages --user .

# 6. Build and Install Caelestia Shell from source (with Debian Patches)
echo "=== Building Caelestia Shell ==="
if [ ! -d "$WORK_DIR/caelestia-shell-git" ]; then
  git clone --recursive https://github.com/caelestia-dots/shell.git "$WORK_DIR/caelestia-shell-git"
fi
cd "$WORK_DIR/caelestia-shell-git"
#git reset --hard
#git apply "$SCRIPT_DIR/patches/caelestia-shell.patch"

rm -rf build
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DINSTALL_QMLDIR=/usr/lib/x86_64-linux-gnu/qt6/qml -DINSTALL_LIBDIR=/usr/local/lib/caelestia -DINSTALL_QSCONFDIR=/etc/xdg/quickshell/caelestia
cmake --build build -j$(nproc)
sudo cmake --install build

# 8. Build and Install qtengine from source (with Debian Patches)
echo "=== Building qtengine  ==="
if [ ! -d "$WORK_DIR/qtengine-src" ]; then
  git clone https://github.com/kossLAN/qtengine.git "$WORK_DIR/qtengine-src"
fi
cd "$WORK_DIR/qtengine-src"
#git reset --hard
#git apply "$SCRIPT_DIR/patches/qtengine.patch"

rm -rf build
cmake -DCMAKE_BUILD_TYPE:STRING=Release -DBUILD_QT5=OFF -B build
cmake --build build -j$(nproc)
sudo cmake --install build

# Symlink plugins to Debian's standard Qt6 path
sudo mkdir -p /usr/lib/x86_64-linux-gnu/qt6/plugins/platformthemes
sudo mkdir -p /usr/lib/x86_64-linux-gnu/qt6/plugins/styles
sudo ln -sf /usr/local/lib/qt6/plugins/platformthemes/libqt6engine-plugin.so /usr/lib/x86_64-linux-gnu/qt6/plugins/platformthemes/libqt6engine-plugin.so
sudo ln -sf /usr/local/lib/qt6/plugins/styles/libqt6engine-style.so /usr/lib/x86_64-linux-gnu/qt6/plugins/styles/libqt6engine-style.so
sudo ldconfig

# 9. Clone Caelestia Dots and Install
echo "=== Installing Caelestia Dots ==="
if [ ! -d "$HOME/caelestia-dots" ]; then
  git clone https://github.com/caelestia-dots/caelestia.git "$HOME/caelestia-dots"
fi
cd "$HOME/caelestia-dots"
# Run Caelestia dots installer
~/.local/bin/caelestia install --noconfirm

# Explicitly copy configuration files to ensure they are properly placed on Debian
echo "=== Configuring Caelestia Dots ==="
mkdir -p "$HOME/.config"
if [ -d "$HOME/caelestia-dots/config" ]; then
  cp -r "$HOME/caelestia-dots/config/"* "$HOME/.config/"
fi

# Set theme to dynamic by default
wget https://images4.alphacoders.com/132/thumb-1920-1322426.jpeg
caelestia wallpaper -f "$HOME/thumb-1920-1322426.jpeg"
~/.local/bin/caelestia scheme set --name dynamic

# 10. Install EasyEffects Dolby Atmos & HIFI Presets
echo "=== Installing EasyEffects Presets ==="
mkdir -p "$HOME/.config/easyeffects/output"
mkdir -p "$HOME/.config/easyeffects/irs"
if [ ! -d "$WORK_DIR/easyeffects-presets-git" ]; then
  git clone https://github.com/JackHack96/EasyEffects-Presets.git "$WORK_DIR/easyeffects-presets-git"
fi
cp "$WORK_DIR/easyeffects-presets-git"/*.json "$HOME/.config/easyeffects/output/"
cp "$WORK_DIR/easyeffects-presets-git"/irs/*.irs "$HOME/.config/easyeffects/irs/"

echo ""
echo "=== Caelestia Debian installation complete! ==="
echo "A reboot is recommended to initialize all settings and environments."
