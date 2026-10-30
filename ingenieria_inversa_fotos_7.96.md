# Ingeniería inversa de Google Fotos 7.96.0 (Video Boost + Pixelify)

- APK: `com.google.android.apps.photos` **7.96.0.996044120** (versionCode 52514915), sacado del Pixel el 2026-10-19.
  `apk\photos_7.96.0\base.apk` SHA-256 `c5a75244…218d56` (ver `SHA256SUMS.txt`).
- Descompilado con jadx 1.5.6 (`tools\jadx-1.5.6`) en `apk\photos_7.96.0\src`: 67 433 archivos, 596 métodos con error.
- Los nombres de clase (`blhg`, `bljj`…) están ofuscados y **cambian con cada versión de Fotos**. Valen solo para 7.96.0.

## 1. Cómo decide Fotos que es un Pixel (cliente)

| Clase | Qué hace (observado en el código) |
|---|---|
| `aykr` (enum) | Generaciones PIXEL_2016…PIXEL_2027_MIDYEAR, cada una con su feature (`…PIXEL_20xx_EXPERIENCE` o `…PIXEL_20xx_PRELOAD`) y tres banderas `v`, `w`, `x`. |
| `aykv` | Recorre el enum de la generación más nueva a la más vieja y devuelve la **primera** feature que `hasSystemFeature` reporta. |
| `ayll` / `aylj` | `PixelOfferDetail{pixelModelName=Build.MODEL, pixelExperience, hasOffer = (generación == PIXEL_2016)}`. |
| `uor`, `rpc` | Calidad y "ilimitado": calidad original ilimitada si `hasOffer`; ahorro de espacio ilimitado si la generación tiene `w` (2017–2020). |
| `rsw` (subida) | Si `Build.MODEL` ∈ {Pixel, Pixel XL, Pixel 2, Pixel 2 XL, Pixel 3, Pixel 3 XL} → `hasPixelSystemFeature`. Solo va a **analítica** (`pji` → proto `cujt`), no a la subida. |

Pixelify ("Pixel XL" + "Pixel 2016"):
- Cambia `Build.BRAND/MANUFACTURER/DEVICE/PRODUCT/MODEL/FINGERPRINT` **una vez**, al cargar Fotos.
- Fuerza a verdadero las features de 2016 y a falso las de 2017–2021.
- **No toca** las de 2022 en adelante.

## 2. Cómo detecta Fotos un Video Boost (cliente)

- `cjey.PIXEL_BLANFORD` es una expresión regular sobre el **nombre del archivo**: `(PXL|PIXEL)_…VB-0n….mp4`.
  `akqw` marca `blanford_format` (1 = crudo, `VB-02`, `svc.STATE_T`) cuando `n == 3`; si no, deja el estado `STATE_R`.
- En el código que arma la subida (`bzq*`, `bzn*`, `blj*`, `blk*`, `ccwo`) **no hay ninguna marca de boost**. El servidor recibe el archivo
  (nombre, XMP `GCamera:GFileMetadata`, pistas `p11-*`) y decide por su cuenta.

## 3. Qué identidad recibe el servidor al subir

1. **Bytes:** `bzqk` hace un POST a `https://photos.googleapis.com/data/upload/uploadmedia/{interactive|background}` con el proto `cnnx`
   (tipo, tamaño, política `bzqi`), la cabecera `X-Goog-Upload-File-Name` y el **User-Agent de Cronet** (`cuan`):
   `com.google.android.apps.photos/<versionCode> (Linux; U; Android <rel>; <locale>; <Build.MODEL>; Build/<Build.ID>; Cronet/…)`.
   El User-Agent se arma una sola vez, cuando arranca Cronet.
2. **Creación del elemento:** RPC `PhotosCreateMediaItems` (servicio `social.frontend.photos.data.v1.PhotosFeService`,
   descriptor `cnok.S`, petición `cndl`, respuesta `cndo`).
   - `cndl.c` = lista de `cndi` ("MediaItemBlueprint"). En `cndi`, **`k` = nombre del archivo** (el mismo valor de `X-Goog-Upload-File-Name`).
   - `cndl.d` = **`cjtj` DeviceInfo** `{c: serial (solo SDK ≤ 25), d: model, e: manufacturer, f: sdk_int}`.
     Lo construye `blhg.a()` (única implementación de `blhf`) **en cada llamada**, leyendo `Build.MODEL` y `Build.MANUFACTURER` en ese momento.
   - `cndl.e` = capacidades del cliente (`cndd`: `OQ_GUARDRAILS_BACKUP_ONLY`, `PC_BAREBONE`). Ninguna es de boost.
   - Solo `blkg.b()` arma la petición, y solo `bljj.a(account, List<cndi>, bzrb)` ("MediaItemCreator") crea un `blkg`.
   - Quién llama:
     - `bzqx` (subida normal): `Collections.singletonList(cndi)`, **un archivo por llamada**.
     - `bznz` ("BatchMediaItemCreator"): **varios archivos por llamada**.

## 4. Inferencias y lo que falta probar

- **Inferencia (no observada en ejecución):** el servidor decide la cuota gratis de Pixel XL **y** si un video es elegible para boost a partir
  del modelo que recibe: el DeviceInfo de `PhotosCreateMediaItems` o el User-Agent. Encaja con las pruebas: con "Pixel XL" se sube gratis
  y sin boost; con el modelo real cobra cuota y se procesa.
- **Desconocido:** si el servidor usa el DeviceInfo, el User-Agent o los dos. Si basta con el DeviceInfo, el hook de la sección 5 es suficiente.
  Si no, también habría que cambiar el User-Agent de esas llamadas.
- **Pendiente:** prueba 2 (COVER con spoof y MAIN sin spoof, `PXL_20261020_021932352`). Si llega su VB-03, basta con cambiar la identidad en el MAIN.

## 5. Hook propuesto (módulo LSPosed aparte; no se toca Pixelify)

- Después de `new blkg(cshs)` (o antes de `bljj.a`), revisar los `cndi.k` de la lista.
  - Si **todos** son archivos `PXL_…VB-0n…mp4`, reemplazar en el `cjtj` (`blkg.e`) el campo `d` (model) por el modelo real
    (`ro.product.model`, "Pixel 9 Pro XL") y el campo `e` (manufacturer) por `ro.product.manufacturer`.
  - Si el lote mezcla archivos de boost con otros, no cambiar nada y dejarlo en el log.
- Es seguro entre hilos: modifica solo el objeto de esa llamada y no toca `Build`, así que las fotos normales siguen como Pixel XL.
- Registrar en el log de LSPosed cada `PhotosCreateMediaItems` con sus nombres de archivo y el modelo enviado.
- Para que sobreviva a cambios de nombres, más adelante se puede localizar con DexKit:
  - `bljj` por la cadena `"MediaItemCreator"`;
  - `blhg` por usar `Build.SERIAL`, `Build.MODEL` y `Build.MANUFACTURER` en un mismo método.
