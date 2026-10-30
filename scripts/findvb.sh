#!/system/bin/sh
# Busca (solo lectura) archivos Video Boost en todo el almacenamiento compartido.
find /data/media/0/ -xdev \( -iname '*VB-0*' -o -iname '*.MAIN.*' \) -exec ls -la {} \; 2>/dev/null
