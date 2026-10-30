#!/system/bin/sh
# Solo lectura: preferencias de Pixelify GPhotos y si su APK esta mapeado en el proceso de Fotos.
PKG=balti.xposed.pixelifygooglephotos
echo "== prefs de la app ($PKG)"
for f in /data/data/$PKG/shared_prefs/*.xml; do [ -f "$f" ] && { echo "--- $f"; ls -la "$f"; cat "$f"; echo; }; done
echo "== prefs remotas de LSPosed (misc_path)"
for d in /data/misc/apexdata/*/prefs/$PKG /data/misc/*/prefs/$PKG; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do [ -f "$f" ] && { echo "--- $f"; ls -la "$f"; cat "$f"; echo; }; done
done
PID=$(pidof com.google.android.apps.photos)
echo "== Fotos PID=$PID; mapeos con pixelify/lspd/xposed"
grep -iE 'pixelify|lspd|xposed|lsposed' /proc/$PID/maps | awk '{print $6}' | sort -u
echo "(fin)"
