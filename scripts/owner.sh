#!/system/bin/sh
# Cambia owner_package_name de filas de MediaStore. Uso: sh owner.sh <paquete> <id> [<id> ...]
# No toca los archivos, solo la fila de MediaStore.
PKG=$1; shift
show() {
  for id in "$@"; do
    content query --uri content://media/external_primary/file --projection _id:_display_name:owner_package_name:generation_modified --where "_id=$id"
  done
}
echo "== antes"; show "$@"
for id in "$@"; do
  echo "== update $id -> $PKG"
  content update --uri content://media/external_primary/file --bind owner_package_name:s:$PKG --where "_id=$id"
  echo "rc=$?"
done
echo "== despues"; show "$@"
