#!/usr/bin/env bash
# Espera (solo lectura) a que llegue <base>.VB-03.MAIN.mp4; cada 5 min registra el MAIN en remote_media.
# Uso (Git Bash): bash esperar_vb03.sh <serial> <base> [minutos_max]
export MSYS_NO_PATHCONV=1
ADB=${ADB:-$(command -v adb || echo "$(cygpath -u "$LOCALAPPDATA")/Android/Sdk/platform-tools/adb.exe")}
S=$1; BASE=$2; MAX=${3:-150}
cd "$(dirname "$0")"
fin=$(( $(date +%s) + MAX * 60 ))
i=0; prev=""
while [ "$(date +%s)" -lt "$fin" ]; do
  cur=$("$ADB" -s "$S" shell "ls -l /sdcard/DCIM/Camera/ | grep '$BASE'" 2>&1)
  vb03=$(echo "$cur" | grep 'VB-03' | awk '{print $5}')
  if [ -n "$vb03" ] && [ "$vb03" = "$prev" ]; then
    echo "$(date +%H:%M:%S) VB-03 llego y esta estable:"; echo "$cur"
    bash poll.sh "$S" "%$BASE%" snap_vb03_llego; exit 0
  fi
  prev=$vb03
  if [ $((i % 5)) -eq 0 ]; then
    r=$(bash poll.sh "$S" "%$BASE%" 2>&1 | sed -n '/== remote_media/,/== media_store/p' | grep 'MAIN' | sed 's/upload_status.*server_creation/server_creation/')
    echo "$(date +%H:%M:%S) archivos: $(echo "$cur" | awk '{print $NF}' | tr '\n' ' ')"
    echo "   remote: $r"
  fi
  i=$((i + 1))
  sleep 60
done
echo "$(date +%H:%M:%S) tiempo agotado sin VB-03"; echo "$cur"; exit 1
