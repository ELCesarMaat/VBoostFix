#!/system/bin/sh
# Vigila los bytes enviados por wlan0 desde que arranca. Si superan el umbral, detiene Fotos (force-stop, no borra nada).
# Uso: sh txguard.sh <umbral_MB> <segundos>
LIM=$(( $1 * 1048576 )); DUR=$2
tx() { sed 's/:/ /' /proc/net/dev | awk '$1=="wlan0" {print $10}'; }
B=$(tx); end=$(( $(date +%s) + DUR )); last=-1
echo "$(date +%H:%M:%S) inicio: umbral ${1} MB, ${DUR} s"
while [ "$(date +%s)" -lt "$end" ]; do
  D=$(( $(tx) - B )); M=$(( D / 1048576 ))
  [ "$M" -ne "$last" ] && echo "$(date +%H:%M:%S) enviados=${M} MB" && last=$M
  if [ "$D" -gt "$LIM" ]; then
    am force-stop com.google.android.apps.photos
    echo "$(date +%H:%M:%S) ABORTADO: se paso el umbral, force-stop de Fotos"; exit 2
  fi
  sleep 1
done
echo "$(date +%H:%M:%S) fin sin pasar el umbral (enviados=${M} MB)"
