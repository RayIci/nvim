#!/usr/bin/env bash
# Inventory import sample for vale
set -euo pipefail

readonly MAX_ITEMS=1000
PATTERN='^[A-Z]{3}-[0-9]{4}$'

# TODO: support stdin
import_file() {
  local file="$1"
  local count=0
  while IFS=, read -r sku price; do
    if [[ ! "$sku" =~ $PATTERN ]]; then
      echo -e "bad sku: ${sku}\n" >&2
      continue
    fi
    count=$((count + 1))
    (( count >= MAX_ITEMS )) && break
    printf '%s\t%.2f\n' "$sku" "$price"
  done < "$file"
  return 0
}

case "${1:-}" in
  -h|--help) echo "usage: $(basename "$0") FILE" ;;
  *) import_file "${1:?missing file}" | sort -u ;;
esac
