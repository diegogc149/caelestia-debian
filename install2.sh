#!/bin/bash
set -e

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

# 2. Install all required system packages
echo "Installing Debian dependencies..."
sudo apt install \
  build-essential cmake ninja-build pkgconf pkg-config \
  qt6-base-dev qt6-base-dev-tools qt6-declarative-dev qt6-declarative-dev-tools \
  qt6-shadertools-dev qt6-wayland-dev qt6-base-private-dev \
  qt6-declarative-private-dev qt6-wayland-private-dev \
  qt6-image-formats-plugins qt6-image-formats-plugin-pdf \
  libdrm-dev spirv-tools libcli11-dev libunwind-dev libdw-dev libjemalloc-dev \
  libcpptrace-dev \
  libwayland-dev wayland-protocols libgbm-dev \
  libxcb1-dev libxcb-composite0-dev libxcb-xfixes0-dev libxcb-damage0-dev \
  libxcb-randr0-dev libxcb-shape0-dev libxcb-util-dev libxcb-keysyms1-dev \
  libxcb-icccm4-dev libxcb-image0-dev libxcb-render-util0-dev \
  libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev \
  libpipewire-0.3-dev libpipewire-0.3-modules \
  libpam0g-dev libpolkit-gobject-1-dev libpolkit-agent-1-dev \
  libglib2.0-dev libglib2.0-bin libglib2.0-dev-bin \
  libqalculate-dev libqalculate23 libaubio-dev libaubio5 libsensors-dev lm-sensors \
  libfftw3-dev libasound2-dev libpulse-dev libtool automake \
  libiniparser-dev libsdl2-dev \
  libnotify-bin libnotify-dev \
  python3 python3-build python3-installer python3-hatch-vcs \
  python3-hatchling python3-venv python-is-python3 \
  fish eza zoxide direnv foot kitty fastfetch btop micro \
  thunar xdg-desktop-portal-gtk \
  papirus-icon-theme adwaita-icon-theme fonts-noto fonts-noto-cjk \
  fonts-noto-color-emoji fonts-cascadia-code \
  gnome-keyring frameworkintegration frameworkintegration6 \
  network-manager bluez bluez-obexd bluez-firmware \
  pipewire pipewire-pulse pipewire-audio pipewire-alsa pipewire-jack \
  wireplumber pavucontrol \
  wl-clipboard cliphist curl git trash-cli jq bc lazygit bat ripgrep ydotool \
  xdg-user-dirs brightnessctl power-profiles-daemon ddcutil swappy \
  grim slurp \
  fonts-noto fonts-noto-cjk fonts-noto-color-emoji \
  unzip meson sassc starship fuzzel hyprpicker \
  hyprland hyprland-dev hyprland-backgrounds hyprland-guiutils \
  hyprland-protocols hyprland-qtutils hyprcursor-util \
  hypridle hyprpaper hyprpolkitagent hyprshade hyprshutdown hyprsunset \
  hyprwayland-scanner \
  xdg-desktop-portal-hyprland \
  python3-pip python3-venv python3-setuptools \
  wf-recorder \
  extra-cmake-modules \
  libkf6colorscheme-dev libkf6config-dev libkf6iconthemes-dev \
  qml6-module-qt5compat-graphicaleffects qml6-module-qtquick-effects \
  easyeffects \
  gpu-screen-recorder-service gpu-screen-recorder-scripts \
  gpu-screen-recorder-dev gpu-screen-recorder-mod \
  glibc-source libgcc-16-dev libgcc-15-dev \
  cava \
  libqalculate-dev \
  qt6-base-dev \
  qt6-declarative-dev \
  firefox-esr \
  zenity uwsm sddm clang gettext \
  libaubio-dev \
  hyprland-guiutils dconf-cli

sudo pip install materialyoucolor --break-system-packages

# 2.5 Install dart-sass (from GitHub releases) into /opt and symlink to /usr/local/bin
echo "=== Checking dart-sass ==="
# dart-sass imprime solo "X.Y.Z" con --version (ruby-sass imprime "Sass 3.x", sassc no provee el comando "sass")
if command -v sass &>/dev/null && sass --version 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
  echo "dart-sass ya está instalado (versión $(sass --version)). Omitiendo instalación."
else
  case "$(uname -m)" in
  x86_64) SASS_ARCH="x64" ;;
  aarch64) SASS_ARCH="arm64" ;;
  *)
    echo "ERROR: Arquitectura no soportada para dart-sass: $(uname -m)"
    exit 1
    ;;
  esac

  # Puedes forzar una versión con: SASS_VERSION=1.90.0 ./install.sh
  if [ -z "${SASS_VERSION:-}" ]; then
    echo "Consultando la última versión de dart-sass..."
    SASS_VERSION="$(curl -fsSL https://api.github.com/repos/sass/dart-sass/releases/latest | jq -r '.tag_name')"
  fi
  if [ -z "$SASS_VERSION" ] || [ "$SASS_VERSION" = "null" ]; then
    echo "ERROR: No se pudo determinar la versión de dart-sass (¿límite de la API de GitHub?)."
    echo "Reintenta especificándola manualmente: SASS_VERSION=1.90.0 ./install.sh"
    exit 1
  fi

  SASS_TARBALL="dart-sass-${SASS_VERSION}-linux-${SASS_ARCH}.tar.gz"
  SASS_URL="https://github.com/sass/dart-sass/releases/download/${SASS_VERSION}/${SASS_TARBALL}"

  echo "Descargando dart-sass ${SASS_VERSION} (${SASS_ARCH})..."
  curl -fLo "$WORK_DIR/$SASS_TARBALL" "$SASS_URL"

  echo "Extrayendo en /opt/dart-sass..."
  sudo rm -rf /opt/dart-sass
  sudo tar -xzf "$WORK_DIR/$SASS_TARBALL" -C /opt # el tarball contiene la carpeta "dart-sass/"
  sudo ln -sf /opt/dart-sass/sass /usr/local/bin/sass
  rm -f "$WORK_DIR/$SASS_TARBALL"

  echo "dart-sass instalado: $(sass --version)"
fi

# 3. Install JetBrains Mono Nerd Font and Material Symbols Rounded fonts (solo si no existen ya en el sistema)
echo "=== Installing Fonts ==="
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
FONT_UPDATED=0

# Busca en TODAS las fuentes que fontconfig conoce (sistema y usuario), no solo en ~/.local/share/fonts
font_installed() {
  fc-list : family 2>/dev/null | grep -qi "$1"
}

if font_installed "JetBrainsMono.*Nerd"; then
  echo "JetBrainsMono Nerd Font ya está instalada. Omitiendo."
else
  echo "Descargando JetBrainsMono Nerd Font..."
  curl -fLo JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
  unzip -o JetBrainsMono.zip
  rm JetBrainsMono.zip
  FONT_UPDATED=1
fi

if font_installed "Material Symbols Rounded"; then
  echo "Material Symbols Rounded ya está instalada. Omitiendo."
else
  echo "Descargando Material Symbols Rounded..."
  curl -fLo "MaterialSymbolsRounded.ttf" "https://github.com/google/material-design-icons/raw/refs/heads/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
  FONT_UPDATED=1
fi

if [ "$FONT_UPDATED" -eq 1 ]; then
  fc-cache -fv
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

# ========================================================================================================================================
# ========================================================================================================================================
echo 'deb http://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_Testing/ /' | sudo tee /etc/apt/sources.list.d/home:AvengeMedia:danklinux.list
curl -fsSL https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/Debian_Testing/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_AvengeMedia_danklinux.gpg > /dev/null
sudo apt update
sudo apt install quickshell-git
# ========================================================================================================================================
# ========================================================================================================================================

# 5. Build and Install Quickshell from source
#echo "=== Building Quickshell from source ==="
#if [ ! -d "$WORK_DIR/quickshell" ]; then
#  git clone --recursive https://github.com/outfoxxed/quickshell.git "$WORK_DIR/quickshell"
#fi
#cd "$WORK_DIR/quickshell"
#rm -rf build
#cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DVENDOR_CPPTRACE=ON -DINSTALL_QMLDIR=/usr/lib/x86_64-linux-gnu/qt6/qml
#cmake --build build -j$(nproc)
#sudo cmake --install build

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
sudo rm -rf /usr/lib/x86_64-linux-gnu/qt6/qml/M3Shapes
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
cd "$HOME/"
wget https://images4.alphacoders.com/132/thumb-1920-1322426.jpeg
~/.local/bin/caelestia wallpaper -f "$HOME/thumb-1920-1322426.jpeg"
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
