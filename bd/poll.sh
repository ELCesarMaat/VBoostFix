#!/usr/bin/env bash
# Snapshot ligero de Fotos (gphotos0.db + media_store_extras) y estado de una grabacion.
# Uso (Git Bash): bash poll.sh <serial> <patron_LIKE> [carpeta_destino]   (destino por defecto: poll_ultimo, se sobrescribe)
export MSYS_NO_PATHCONV=1
ADB=${ADB:-$(command -v adb || echo "$(cygpath -u "$LOCALAPPDATA")/Android/Sdk/platform-tools/adb.exe")}
S=$1; PAT=$2
cd "$(dirname "$0")"
OUT=${3:-poll_ultimo}
"$ADB" -s "$S" shell "su -c 'sh /data/local/tmp/copydb_min.sh'" >/dev/null || { echo "fallo copydb_min"; exit 1; }
rm -rf "$OUT"; mkdir -p "$OUT"
for f in gphotos0.db gphotos0.db-wal gphotos0.db-shm media_store_extras media_store_extras-wal media_store_extras-shm; do
  "$ADB" -s "$S" pull "/data/local/tmp/boostdb_min/$f" "$OUT/$f" >/dev/null 2>&1
done
echo "== snapshot $(date +%H:%M:%S) -> bd/$OUT"
python estado_boost.py "$OUT" "$PAT"
