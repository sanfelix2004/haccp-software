#!/usr/bin/env bash
# Pulizia automatica archivio PDF HACCP Manager (simulatore).
#
# Uso:
#   ./scripts/clear-haccp-pdfs.sh           # solo file PDF su disco
#   ./scripts/clear-haccp-pdfs.sh --auto    # tutto: PDF + marker → app cancella record e rigenera

set -euo pipefail

BUNDLE_ID="com.haccpmanager.app"
SCHEME="HACCP Manager"
SIMULATOR_NAME="iPhone 17"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"

marker_name="HACCP_PURGE_DOCUMENTS.request"

remove_pdfs_in() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  find "$root" -type f \( -iname '*.pdf' -o -iname '*.csv' \) -delete 2>/dev/null || true
  if [[ -d "$root/HACCPDocumentiEsportazioneTemp" ]]; then
    rm -rf "$root/HACCPDocumentiEsportazioneTemp"
  fi
}

find_app_containers() {
  local sim_root="$HOME/Library/Developer/CoreSimulator/Devices"
  [[ -d "$sim_root" ]] || return 0
  find "$sim_root" -path "*/Library/Preferences/${BUNDLE_ID}.plist" 2>/dev/null | while read -r plist; do
    dirname "$(dirname "$(dirname "$plist")")"
  done
}

boot_simulator() {
  if xcrun simctl list devices booted 2>/dev/null | grep -q Booted; then
    return 0
  fi
  echo "▶ Avvio simulatore $SIMULATOR_NAME..."
  local udid
  udid=$(xcrun simctl list devices available -j 2>/dev/null | python3 -c "
import json,sys
name=sys.argv[1]
for rt,dlist in json.load(sys.stdin).get('devices',{}).items():
  for d in dlist:
    if d.get('name')==name and d.get('isAvailable',True):
      print(d['udid']); raise SystemExit
" "$SIMULATOR_NAME" 2>/dev/null || true)
  if [[ -n "$udid" ]]; then
    xcrun simctl boot "$udid" 2>/dev/null || true
  else
    xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true
  fi
  open -a Simulator 2>/dev/null || true
  for _ in {1..30}; do
    xcrun simctl list devices booted 2>/dev/null | grep -q Booted && return 0
    sleep 1
  done
  echo "✗ Simulatore non avviato."
  exit 1
}

build_and_install() {
  echo "▶ Build e installazione app..."
  cd "$REPO_ROOT"
  xcodebuild \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -derivedDataPath "$REPO_ROOT/.derivedData" \
    build \
    | tail -3

  local app_path="$REPO_ROOT/.derivedData/Build/Products/Debug-iphonesimulator/HACCP Manager.app"
  if [[ ! -d "$app_path" ]]; then
    app_path=$(find "$REPO_ROOT/.derivedData" -name "HACCP Manager.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)
  fi
  if [[ ! -d "$app_path" ]]; then
    echo "✗ App non trovata dopo la build."
    exit 1
  fi

  xcrun simctl install booted "$app_path"
  echo "  ✓ Installata: $app_path"
}

write_purge_marker() {
  local container="$1"
  local support="$container/Library/Application Support"
  mkdir -p "$support"
  echo -n "purge" > "$support/$marker_name"
  echo "  ✓ Marker purge creato"
}

launch_app() {
  echo "▶ Avvio app (purge + rigenerazione automatica)..."
  xcrun simctl launch booted "$BUNDLE_ID" 2>/dev/null || true
}

echo "🧹 HACCP — pulizia archivio PDF"
echo ""

if [[ "$MODE" == "--auto" ]]; then
  boot_simulator
  build_and_install

  CONTAINER=$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null || true)
  if [[ -z "$CONTAINER" || ! -d "$CONTAINER" ]]; then
    echo "✗ Container app non trovato."
    exit 1
  fi

  echo "[$BUNDLE_ID]"
  remove_pdfs_in "$CONTAINER/Library/Application Support/HACCPManager"
  write_purge_marker "$CONTAINER"
  launch_app
  echo ""
  echo "✅ Fatto. L'app al prossimo foreground cancella i record documenti e rigenera l'archivio."
  echo "   Apri il simulatore se non è in primo piano e attendi qualche secondo."
  exit 0
fi

# Modalità manuale: solo file PDF
FOUND=0
if CONTAINER=$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null); then
  echo "[simulatore avviato]"
  remove_pdfs_in "$CONTAINER/Library/Application Support/HACCPManager"
  echo "  ✓ PDF rimossi"
  FOUND=1
else
  while read -r container; do
    [[ -n "$container" ]] || continue
    remove_pdfs_in "$container/Library/Application Support/HACCPManager"
    echo "  ✓ PDF rimossi in $(basename "$(dirname "$(dirname "$container")")")"
    FOUND=1
  done < <(find_app_containers)
fi

if [[ "$FOUND" -eq 0 ]]; then
  echo "Nessun container. Usa: ./scripts/clear-haccp-pdfs.sh --auto"
  exit 1
fi

echo ""
echo "PDF eliminati. Per purge completo + rigenerazione: ./scripts/clear-haccp-pdfs.sh --auto"
