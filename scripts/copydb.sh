#!/system/bin/sh
# Copia en caliente (solo lectura sobre el origen) de databases y shared_prefs de Fotos y Camara.
# Uso: sh copydb.sh list   -> solo muestra tamanos
#      sh copydb.sh copy   -> copia a /data/local/tmp/boostdb
OUT=/data/local/tmp/boostdb
for P in com.google.android.apps.photos com.google.android.GoogleCamera; do
  for D in databases shared_prefs; do
    SRC=/data/data/$P/$D
    [ -d "$SRC" ] || continue
    if [ "$1" = "list" ]; then
      echo "== $SRC"; du -sh "$SRC"; ls -la "$SRC" | grep -E '\.(db|xml)(-wal|-shm|-journal)?$' | awk '{print $5, $NF}' | sort -rn | head -n 40
    else
      mkdir -p "$OUT/$P/$D"
      # cp -p de cada db junto con su -wal/-shm en el mismo paso para minimizar desfase
      cp -p "$SRC"/* "$OUT/$P/$D/" 2>/dev/null
    fi
  done
done
if [ "$1" = "copy" ]; then
  chown -R shell:shell "$OUT"; chmod -R a+rX "$OUT"; du -sh "$OUT"
fi
