#!/usr/bin/env bash
# Espera (solo lectura) a que llegue el VB-03.MAIN de varias grabaciones; cada 5 min registra sus MAIN en remote_media.
# Uso (Git Bash): bash esperar_vb03_varios.sh <serial> <minutos_max> <base1> [base2 ...]
export MSYS_NO_PATHCONV=1
ADB=${ADB:-$(command -v adb || echo "$(cygpath -u "$LOCALAPPDATA")/Android/Sdk/platform-tools/adb.exe")}
S=$1; MAX=$2; shift 2
BASES="$*"
cd "$(dirname "$0")"
fin=$(( $(date +%s) + MAX * 60 ))
i=0; listos=""
while [ "$(date +%s)" -lt "$fin" ]; do
  ls_out=$("$ADB" -s "$S" shell "ls -l /sdcard/DCIM/Camera/ | grep VB-03" 2>&1)
  pendientes=0
  for b in $BASES; do
    case " $listos " in *" $b "*) continue ;; esac
    if echo "$ls_out" | grep -q "$b.VB-03"; then
      echo "$(date +%H:%M:%S) LLEGO VB-03 de $b: $(echo "$ls_out" | grep "$b" | awk '{print $5, $NF}')"
      listos="$listos $b"
    else
      pendientes=$((pendientes + 1))
    fi
  done
  if [ "$pendientes" -eq 0 ]; then
    echo "$(date +%H:%M:%S) todos llegaron"; bash poll.sh "$S" '%VB-0%' snap_vb03_todos >/dev/null 2>&1; exit 0
  fi
  if [ $((i % 5)) -eq 0 ]; then
    for b in $BASES; do
      r=$(bash poll.sh "$S" "%$b%" 2>&1 | sed -n '/== remote_media/,/== media_store/p' | grep 'MAIN' | sed 's/upload_status.*size_bytes/size_bytes/;s/height=[0-9]*  server_creation_timestamp=//')
      echo "$(date +%H:%M:%S) $b remote: $r"
    done
  fi
  i=$((i + 1))
  sleep 60
done
echo "$(date +%H:%M:%S) tiempo agotado; faltan: $BASES (listos:$listos)"; exit 1
