#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp)"
swiftc -DDEBUG -o "$OUT" \
  "$ROOT/haccp-software/HACCPManager/Core/OCR/ExpiryDateParser.swift" \
  "$ROOT/haccp-software/HACCPManager/Core/Utilities/HACCPDateNormalizer.swift" \
  "$ROOT/haccp-software/HACCPManager/Core/LabelCapture/LabelLotTypes.swift" \
  "$ROOT/haccp-software/HACCPManager/Core/LabelCapture/LabelStampLineParser.swift" \
  "$ROOT/scripts/lot_parser_check_main.swift"
"$OUT"
rm -f "$OUT"
