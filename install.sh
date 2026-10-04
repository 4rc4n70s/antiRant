#!/usr/bin/env bash
# Instala antiRant como perfil de voxtype + atajo en Hyprland.
# Se puede correr varias veces: sólo agrega lo que falta.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="$HOME/.config/antirant/gemini_key"
VOXTYPE_CONFIG="$HOME/.config/voxtype/config.toml"
HYPR_BINDINGS="$HOME/.config/hypr/bindings.lua"
HOTKEY="${ANTIRANT_HOTKEY:-SUPER + ALT + R}"

# 0. Requisitos
command -v voxtype >/dev/null || { echo "✗ voxtype no está instalado" >&2; exit 1; }
[[ -f "$VOXTYPE_CONFIG" ]] || { echo "✗ No existe $VOXTYPE_CONFIG (corré 'voxtype setup')" >&2; exit 1; }
python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' ||
  { echo "✗ Hace falta Python 3.11 o superior" >&2; exit 1; }

chmod +x "$APP_DIR/antirant"

# 1. API key de Gemini (archivo con permisos 600, fuera del repo)
if [[ -s "$KEY_FILE" ]]; then
  echo "✓ API key ya configurada en $KEY_FILE"
else
  read -rsp "Pegá tu API key de Gemini: " key
  echo
  mkdir -p "$(dirname "$KEY_FILE")"
  (umask 077 && printf '%s\n' "$key" >"$KEY_FILE")
  echo "✓ API key guardada en $KEY_FILE"
fi

# 2. Perfil en voxtype
if grep -q '^\[profiles\.antirant\]' "$VOXTYPE_CONFIG"; then
  echo "✓ Perfil antirant ya existe en voxtype"
else
  cp "$VOXTYPE_CONFIG" "$VOXTYPE_CONFIG.antirant.bak"
  cat >>"$VOXTYPE_CONFIG" <<EOF

# antiRant: limpia el dictado con Gemini (ver $APP_DIR)
[profiles.antirant]
post_process_command = "$APP_DIR/antirant"
post_process_timeout_ms = 6000
EOF
  echo "✓ Perfil antirant agregado a voxtype (backup: $VOXTYPE_CONFIG.antirant.bak)"
fi

# 3. Atajo en Hyprland (Omarchy, bindings.lua)
hotkey_in_use() {
  # "SUPER + ALT + R" -> mods "SUPER ALT", key "R"
  local key="${HOTKEY##*+ }" mods="${HOTKEY% + *}"
  mods="${mods// + / }"
  omarchy menu keybindings --print 2>/dev/null | grep -qiE "^${mods} \+ ${key} +→"
}

if [[ ! -f "$HYPR_BINDINGS" ]]; then
  echo "! No encontré $HYPR_BINDINGS: agregá el atajo a mano (ver README)"
elif grep -q 'profile antirant' "$HYPR_BINDINGS"; then
  echo "✓ Atajo ya existe en Hyprland"
elif hotkey_in_use; then
  echo "! $HOTKEY ya está en uso: no agrego el atajo."
  echo "  Elegí otro con: ANTIRANT_HOTKEY=\"SUPER + ALT + X\" ./install.sh"
else
  cp "$HYPR_BINDINGS" "$HYPR_BINDINGS.antirant.bak"
  cat >>"$HYPR_BINDINGS" <<EOF

-- antiRant: dictado + limpieza con IA (ver $APP_DIR).
o.bind("$HOTKEY", "Dictado limpio (antiRant)", "voxtype record toggle --profile antirant")
EOF
  echo "✓ Atajo $HOTKEY agregado (backup: $HYPR_BINDINGS.antirant.bak)"
fi

# 4. Recargar
systemctl --user restart voxtype.service
hyprctl reload >/dev/null 2>&1 || true
echo "✓ voxtype reiniciado y Hyprland recargado"
echo
echo "Probalo: $HOTKEY para empezar a hablar, $HOTKEY de nuevo para terminar."
