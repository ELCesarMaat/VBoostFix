#!/system/bin/sh
# Consulta MediaStore (solo lectura) para los archivos Video Boost y, si se indica, un video normal de control.
# Uso: sh mq.sh [nombre_del_video_de_control]
WHERE="_display_name LIKE '%VB-0%'"
[ -n "$1" ] && WHERE="$WHERE OR _display_name = '$1'"
for v in external_primary; do
  echo "===== files ($v) ====="
  content query --uri content://media/$v/file \
    --where "$WHERE" \
    | tr ',' '\n' | sed 's/^ *//'
done
