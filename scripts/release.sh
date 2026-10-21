#!/bin/bash
# Publica una versión nueva de GitSwitcher:
#   1. Compila la app en Release (sin firmar con Developer ID).
#   2. La empaqueta en dist/GitSwitcher-<versión>.zip.
#   3. Crea la release v<versión> en GitHub y sube el zip.
#   4. Actualiza el cask en el tap de Homebrew.
#
# Uso: scripts/release.sh 1.0.0
#
# Todo lo que se publica fuera (release y tap) se hace con la cuenta dueña del
# repo (OWNER), sea cual sea la cuenta activa de gh, y pidiendo confirmación.
set -euo pipefail

OWNER="marcosesperon"
REPO="$OWNER/GitSwitcher"
TAP_REPO="$OWNER/homebrew-tap"
APP_NAME="GitSwitcher"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# --- Ayudas -------------------------------------------------------------------

fail() { echo "✖ $*" >&2; exit 1; }
step() { echo; echo "▸ $*"; }

# Pregunta sí/no; cualquier cosa que no sea «s» o «y» cuenta como no.
confirm() {
  read -r -p "$1 [s/N] " answer
  [[ "$answer" =~ ^[sSyY]$ ]]
}

# --- Comprobaciones previas -----------------------------------------------------

VERSION="${1:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Indica la versión como X.Y.Z, por ejemplo: scripts/release.sh 1.0.0"
TAG="v$VERSION"

for tool in gh xcodegen xcodebuild ditto shasum; do
  command -v "$tool" >/dev/null || fail "Falta '$tool' en el PATH."
done

# Usamos el token de la cuenta dueña solo dentro de este script. Así da igual
# qué cuenta tengas activa en gh, y git (que pide credenciales a gh) también la usa.
GH_TOKEN="$(gh auth token --hostname github.com --user "$OWNER" 2>/dev/null)" \
  || fail "gh no tiene sesión iniciada con la cuenta '$OWNER'."
export GH_TOKEN

# La release se crea a partir de lo que hay en GitHub, así que lo local tiene que
# estar limpio y subido.
[[ -z "$(git status --porcelain)" ]] || fail "Hay cambios sin commitear."
git fetch --quiet origin
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] \
  || fail "HEAD no coincide con origin/main. Sube (o actualiza) la rama antes de publicar."
gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 && fail "La release $TAG ya existe."

# --- Compilación y empaquetado -------------------------------------------------

BUILD_DIR="$ROOT/build/release"
DIST_DIR="$ROOT/dist"
ZIP="$DIST_DIR/$APP_NAME-$VERSION.zip"
BUILD_NUMBER="$(git rev-list --count HEAD)"

step "Generando el proyecto y compilando $TAG (build $BUILD_NUMBER)…"
xcodegen generate --quiet
rm -rf "$BUILD_DIR"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" -destination "generic/platform=macOS" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY="-" \
  build -quiet

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || fail "No se encuentra $APP tras compilar."

step "Empaquetando…"
mkdir -p "$DIST_DIR"
rm -f "$ZIP"
# ditto conserva los atributos del bundle; un zip normal puede romper la app.
ditto -c -k --keepParent "$APP" "$ZIP"
SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "  $ZIP"
echo "  sha256 $SHA256"

# --- Publicación ----------------------------------------------------------------

echo
confirm "¿Publicar la release $TAG en $REPO y actualizar $TAP_REPO?" || fail "Cancelado. El zip queda en $ZIP."

step "Creando la release $TAG…"
gh release create "$TAG" "$ZIP" --repo "$REPO" --target main --title "$APP_NAME $VERSION" --generate-notes

step "Actualizando el cask en $TAP_REPO…"
if ! gh repo view "$TAP_REPO" >/dev/null 2>&1; then
  confirm "El repositorio $TAP_REPO no existe. ¿Crearlo como público?" \
    || fail "Release publicada, pero el cask no se ha actualizado."
  gh repo create "$TAP_REPO" --public --description "Homebrew tap for $OWNER's apps" --add-readme
fi

TAP_DIR="$(mktemp -d)"
trap 'rm -rf "$TAP_DIR"' EXIT
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --quiet
mkdir -p "$TAP_DIR/Casks"
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA256/" -e "s#__REPO__#$REPO#g" \
  packaging/gitswitcher.rb.template > "$TAP_DIR/Casks/gitswitcher.rb"

# El commit del tap lleva el mismo autor que este repositorio (su git config
# local), no el global: así no se cuela, por ejemplo, un correo del trabajo.
git -C "$TAP_DIR" add Casks/gitswitcher.rb
git -C "$TAP_DIR" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
  commit --quiet -m "gitswitcher $VERSION"
git -C "$TAP_DIR" push --quiet

echo
echo "✔ Publicado $TAG."
echo "  Instalar: brew install --cask $OWNER/tap/gitswitcher"
