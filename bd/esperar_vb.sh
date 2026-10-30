#!/usr/bin/env bash
# Espera (solo lectura) a que aparezca un *.VB-02.MAIN.mp4 nuevo en DCIM/Camera y a que deje de crecer.
# Uso (Git Bash): bash esperar_vb.sh <serial> [minutos_max]
export MSYS_NO_PATHCONV=1
ADB=${ADB:-$(command -v adb || echo "$(cygpath -u "$LOCALAPPDATA")/Android/Sdk/platform-tools/adb.exe")}
S=$1; MAX=${2:-40}
fin=$(( $(date +%s) + MAX * 60 ))
prev=""
while [ "$(date +%s)" -lt "$fin" ]; do
  cur=$("$ADB" -s "$S" shell "ls -l /sdcard/DCIM/Camera/ | grep 'VB-0[12]'" 2>&1 | grep 'VB-02.MAIN' | awk '{print $5, $NF}')
  if [ -n "$cur" ] && [ "$cur" = "$prev" ]; then
    echo "$(date +%H:%M:%S) VB-02 estable:"; "$ADB" -s "$S" shell "ls -la /sdcard/DCIM/Camera/ | grep VB-0"; exit 0
  fi
  [ -n "$cur" ] && echo "$(date +%H:%M:%S) creciendo: $cur"
  prev=$cur
  sleep 10
done
echo "$(date +%H:%M:%S) tiempo agotado sin VB-02 nuevo"; exit 1
