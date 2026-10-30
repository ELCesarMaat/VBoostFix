#!/system/bin/sh
# Estado (solo lectura): uptime, scope de LSPosed para Fotos y archivos de una grabacion.
# Uso: sh estado.sh [patron]   (por defecto VB-0)
echo "== uptime"; uptime
echo "== LSPosed: modulos con Fotos en su scope"
CFG=/data/adb/lspd/config/modules_config.db
if [ -f "$CFG" ]; then
  cp "$CFG" /data/local/tmp/lspd_cfg.db
  for s in -wal -shm; do [ -f "$CFG$s" ] && cp "$CFG$s" "/data/local/tmp/lspd_cfg.db$s"; done
  chmod 644 /data/local/tmp/lspd_cfg.db*
  echo "(copiado a /data/local/tmp/lspd_cfg.db para leerlo en el PC)"
else
  echo "no existe $CFG"
fi
echo "== archivos ${1:-VB-0} en DCIM (incluye .trashed-)"
ls -la /data/media/0/DCIM/Camera/ | grep -- "${1:-VB-0}"
echo "(fin)"
