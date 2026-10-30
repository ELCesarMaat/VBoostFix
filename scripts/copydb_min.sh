#!/system/bin/sh
# Copia en caliente (solo lectura sobre el origen) de gphotos0.db y media_store_extras con sus -wal/-shm.
OUT=/data/local/tmp/boostdb_min
SRC=/data/data/com.google.android.apps.photos/databases
rm -rf "$OUT"; mkdir -p "$OUT"
for f in gphotos0.db gphotos0.db-wal gphotos0.db-shm media_store_extras media_store_extras-wal media_store_extras-shm; do
  [ -f "$SRC/$f" ] && cp -p "$SRC/$f" "$OUT/"
done
chown -R shell:shell "$OUT"; chmod -R a+rX "$OUT"; ls -la "$OUT"
