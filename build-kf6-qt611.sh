#!/bin/bash
# =============================================================================
# build-kf6-qt611.sh
#
# Recompila (como un binNMU local) los paquetes KF6 de Debian que dependen de
# la ABI privada de Qt, contra el Qt 6.11.x que ya tienes instalado desde
# experimental.
#
# Por qué hace falta: los KF6 de sid (6.30.0-1) están compilados contra Qt 6.10.2
# y dependen de "qt6-base-private-abi (= 6.10.2)". Al subir a Qt 6.11.2, apt los
# quita. Este script baja el código fuente Debian de esos paquetes, los compila
# contra tu Qt 6.11 y los instala con la versión "X+b1", que es más nueva que la
# de sid, así que apt no intentará reemplazarlos.
#
# Uso:
#   ./build-kf6-qt611.sh                 # recompila los 4 paquetes necesarios para qtengine
#   ./build-kf6-qt611.sh kf6-kwindowsystem kf6-kdbusaddons
#                                        # añade más paquetes fuente AL FINAL de la lista
#   ./build-kf6-qt611.sh --force         # recompila aunque ya esté hecho para este Qt
#
# Variables de entorno opcionales:
#   WORK_DIR=$HOME/caelestia-build   Directorio de trabajo
#   SRC_SUITE=unstable               Suite de la que se baja el código fuente
#   APT_TARGET=experimental          Suite preferida para resolver build-deps ("" para desactivar)
#
# Ejecútalo DESPUÉS de instalar Qt 6.11 desde experimental.
# =============================================================================
set -euo pipefail

WORK_DIR="${WORK_DIR:-$HOME/caelestia-build}"
KF6_DIR="$WORK_DIR/kf6-rebuild"
SRC_SUITE="${SRC_SUITE:-unstable}"
APT_TARGET="${APT_TARGET-experimental}"
FORCE=0

# Paquetes fuente a recompilar, EN ORDEN DE DEPENDENCIA (cada uno necesita al anterior):
#   kguiaddons -> kcolorscheme -> kconfigwidgets -> kiconthemes
# Esto cubre libkf6colorscheme-dev, libkf6iconthemes-dev y libkf6configwidgets-dev,
# que es lo que necesita qtengine. libkf6config-dev (kf6-kconfig) no requiere recompilación.
DEFAULT_KF6_PACKAGES=(
  kf6-kguiaddons
  kf6-kcolorscheme
  kf6-kconfigwidgets
  kf6-kiconthemes
)
EXTRA_PACKAGES=()

# Paquetes -dev que se verifican al final
VERIFY_PACKAGES=(
  libkf6config-dev
  libkf6guiaddons-dev
  libkf6colorscheme-dev
  libkf6configwidgets-dev
  libkf6iconthemes-dev
)

usage() {
  sed -n '3,26p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--force) FORCE=1 ;;
    -h|--help)  usage; exit 0 ;;
    -*)         echo "Opción desconocida: $1"; usage; exit 1 ;;
    *)          EXTRA_PACKAGES+=("$1") ;;
  esac
  shift
done

PACKAGES=("${DEFAULT_KF6_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}")

echo "=== Recompilación de KF6 contra Qt 6.11 ==="
echo "Directorio de trabajo: $KF6_DIR"
echo ""

# -----------------------------------------------------------------------------
# 0. Comprobaciones previas
# -----------------------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
  echo "ERROR: No ejecutes este script como root. Usa tu usuario normal (pedirá sudo cuando haga falta)."
  exit 1
fi

if ! command -v sudo &> /dev/null; then
  echo "ERROR: sudo no está instalado."
  exit 1
fi

pkg_version() {
  dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true
}

QT_VER="$(pkg_version qt6-base-dev)"
QT_DECL_VER="$(pkg_version qt6-declarative-dev)"

case "$QT_VER" in
  6.11.*) ;;
  *)
    echo "ERROR: qt6-base-dev instalado es '${QT_VER:-ninguno}', pero se necesita Qt 6.11.x."
    echo "Instala primero Qt 6.11 desde experimental y vuelve a ejecutar este script."
    echo "(Compilar contra 6.10 daría los mismos paquetes que ya trae sid.)"
    exit 1
    ;;
esac

case "$QT_DECL_VER" in
  6.11.*) ;;
  *)
    echo "ERROR: qt6-base-dev es $QT_VER pero qt6-declarative-dev es '${QT_DECL_VER:-ninguno}'."
    echo "Ambos deben estar en 6.11.x antes de compilar."
    exit 1
    ;;
esac

echo "Qt detectado: qt6-base-dev $QT_VER / qt6-declarative-dev $QT_DECL_VER"
QT_TAG="${QT_VER//[^A-Za-z0-9.+-]/_}"

# Mantener la sesión de sudo viva durante compilaciones largas
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &> /dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# -----------------------------------------------------------------------------
# 1. Herramientas de empaquetado
# -----------------------------------------------------------------------------
echo ""
echo "=== Instalando herramientas de empaquetado ==="
sudo apt-get install -y --no-install-recommends \
  build-essential devscripts dpkg-dev fakeroot debhelper

# -----------------------------------------------------------------------------
# 2. Asegurar que hay código fuente (deb-src) disponible
# -----------------------------------------------------------------------------
echo ""
echo "=== Comprobando repositorios de código fuente (deb-src) ==="

# OJO: "apt-cache showsrc" devuelve código 0 aunque el paquete no exista (basta con que
# haya CUALQUIER línea deb-src), así que se comprueba la SALIDA, no el código de retorno.
source_versions() {
  local out
  out="$(apt-cache showsrc "$1" 2>/dev/null || true)"
  sed -n 's/^Version: //p' <<< "$out"
}

FOUND_VERS="$(source_versions "${PACKAGES[0]}")"
if [ -n "$FOUND_VERS" ]; then
  echo "Código fuente de ${PACKAGES[0]} disponible (versiones: $(tr '\n' ' ' <<< "$FOUND_VERS"))"
else
  echo "No hay código fuente de ${PACKAGES[0]} en tus deb-src actuales."
  echo "Añadiendo $SRC_SUITE en /etc/apt/sources.list.d/caelestia-debsrc.sources"
  KEYRING=""
  for k in /usr/share/keyrings/debian-archive-keyring.pgp /usr/share/keyrings/debian-archive-keyring.gpg; do
    if [ -f "$k" ]; then KEYRING="$k"; break; fi
  done
  {
    echo "Types: deb-src"
    echo "URIs: http://deb.debian.org/debian"
    echo "Suites: $SRC_SUITE"
    echo "Components: main"
    if [ -n "$KEYRING" ]; then echo "Signed-By: $KEYRING"; fi
  } | sudo tee /etc/apt/sources.list.d/caelestia-debsrc.sources > /dev/null
  sudo apt-get update

  FOUND_VERS="$(source_versions "${PACKAGES[0]}")"
  if [ -z "$FOUND_VERS" ]; then
    echo "ERROR: Sigue sin haber código fuente de ${PACKAGES[0]} tras añadir deb-src ($SRC_SUITE)."
    echo "--- Líneas deb-src actuales:"
    grep -rHE '^(deb-src|Types:.*deb-src)' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || true
    echo "--- Revisa también los mensajes de 'apt-get update' (errores de firma/Signed-By)."
    exit 1
  fi
  echo "Código fuente de ${PACKAGES[0]} disponible (versiones: $(tr '\n' ' ' <<< "$FOUND_VERS"))"
fi

# Suite preferida para resolver build-deps (para que las librerías Qt salgan de experimental)
APT_TARGET_OPT=()
if [ -n "$APT_TARGET" ]; then
  APT_POLICY="$(apt-cache policy)"
  if grep -q "a=$APT_TARGET" <<< "$APT_POLICY"; then
    APT_TARGET_OPT=(-t "$APT_TARGET")
  else
    echo "AVISO: '$APT_TARGET' no está en tus fuentes de apt; se resolverán build-deps sin -t."
  fi
fi

# -----------------------------------------------------------------------------
# 3. Recompilar cada paquete
# -----------------------------------------------------------------------------
mkdir -p "$KF6_DIR"
export DEBFULLNAME="Local rebuild"
export DEBEMAIL="local@localhost"

install_built_debs() {
  local pdir="$1"
  local debs=()
  mapfile -t debs < <(find "$pdir" -maxdepth 1 -name '*.deb' | sort)
  if [ "${#debs[@]}" -eq 0 ]; then
    echo "ERROR: no se encontraron .deb en $pdir"
    return 1
  fi
  echo "Instalando ${#debs[@]} paquetes de $(basename "$pdir")..."
  sudo apt-get install -y "${debs[@]}"
}

rebuild_pkg() {
  local pkg="$1"
  local pdir="$KF6_DIR/$pkg"
  local marker="$pdir/.built-against-$QT_TAG"

  echo ""
  echo "=== [$pkg] ==="

  if [ -f "$marker" ] && [ "$FORCE" -eq 0 ]; then
    echo "Ya compilado contra Qt $QT_VER. Omitiendo compilación (usa --force para rehacer)."
    install_built_debs "$pdir"
    return 0
  fi

  rm -rf "$pdir"
  mkdir -p "$pdir"
  cd "$pdir"

  echo "Descargando código fuente..."
  apt-get source --only-source "$pkg"

  local srcdir
  srcdir="$(find "$pdir" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  if [ -z "$srcdir" ]; then
    echo "ERROR: no se extrajo el código fuente de $pkg"
    return 1
  fi
  cd "$srcdir"

  echo "Instalando dependencias de compilación..."
  sudo apt-get build-dep -y --arch-only "${APT_TARGET_OPT[@]}" ./

  echo "Preparando binNMU local (versión +b1)..."
  dch --bin-nmu "Reconstruido localmente contra Qt $QT_VER"

  echo "Compilando (esto puede tardar)..."
  DEB_BUILD_OPTIONS="nocheck noautodbgsym parallel=$(nproc)" dpkg-buildpackage -B -uc -us

  cd "$pdir"
  install_built_debs "$pdir"

  touch "$marker"
  echo "[$pkg] listo."
}

for pkg in "${PACKAGES[@]}"; do
  rebuild_pkg "$pkg"
done

# -----------------------------------------------------------------------------
# 4. Paquetes -dev que no requieren recompilación pero qtengine necesita
# -----------------------------------------------------------------------------
echo ""
echo "=== Asegurando libkf6config-dev ==="
sudo apt-get install -y libkf6config-dev

# -----------------------------------------------------------------------------
# 5. Verificación
# -----------------------------------------------------------------------------
echo ""
echo "=== Verificación ==="
MISSING=0
for p in "${VERIFY_PACKAGES[@]}"; do
  if v="$(dpkg-query -W -f='${Package} ${Version} (${Status})\n' "$p" 2>/dev/null)" && grep -q "install ok installed" <<< "$v"; then
    echo "OK     $v"
  else
    echo "FALTA  $p"
    MISSING=1
  fi
done

echo ""
if [ "$MISSING" -eq 0 ]; then
  echo "=== KF6 recompilado contra Qt $QT_VER ==="
  echo "Ya puedes recompilar quickshell, m3shapes, caelestia-shell y qtengine (install.sh)."
else
  echo "AVISO: faltan algunos paquetes -dev (ver arriba). Si alguno es de otro paquete fuente,"
  echo "añádelo como argumento, en orden de dependencia:  $0 <paquete-fuente>"
  exit 1
fi
