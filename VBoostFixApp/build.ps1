# Builds VBoostFix.apk (modulo LSPosed) without Gradle: aapt2 -> javac -> d8 -> aapt add -> zipalign -> apksigner.
# La API de Xposed (tools\xposed-api-82\api-82.jar) solo se usa para compilar; no se mete en el APK.
# Si falta, se descarga del repositorio Maven oficial (api.xposed.info) y se comprueba su SHA-256.
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
# Rutas por defecto de Android Studio en Windows; se pueden cambiar con ANDROID_HOME, BUILD_TOOLS y JAVA_HOME.
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$bt = Join-Path $sdk ('build-tools\' + $(if ($env:BUILD_TOOLS) { $env:BUILD_TOOLS } else { '37.0.0' }))
$androidJar = Join-Path $sdk 'platforms\android-36\android.jar'
$xposedJar = Join-Path $root '..\tools\xposed-api-82\api-82.jar'
$xposedUrl = 'https://api.xposed.info/de/robv/android/xposed/api/82/api-82.jar'
$xposedSha256 = 'F48C635F1C7469FDEC0E00AD2EA0B7A6B2F5B55065784A35B7CA3A84615E8E25'
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr' }
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$build = Join-Path $root 'build'

function Invoke-Step([string]$name, [scriptblock]$cmd) {
    Write-Host "== $name =="
    & $cmd
    if ($LASTEXITCODE -ne 0) { throw "Fallo el paso '$name' (codigo $LASTEXITCODE)" }
}

if (-not (Test-Path $xposedJar)) {
    Write-Host "== descargando $xposedUrl =="
    New-Item -ItemType Directory -Force (Split-Path $xposedJar) | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri $xposedUrl -OutFile $xposedJar
}
if ((Get-FileHash -Algorithm SHA256 $xposedJar).Hash -ne $xposedSha256) { throw "El SHA-256 de $xposedJar no coincide" }
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory -Force "$build\gen", "$build\classes", "$build\dex" | Out-Null

Invoke-Step 'aapt2 compile' { & "$bt\aapt2.exe" compile --dir "$root\res" -o "$build\res.zip" }
Invoke-Step 'aapt2 link' {
    & "$bt\aapt2.exe" link -o "$build\app-res.apk" -I $androidJar --manifest "$root\AndroidManifest.xml" `
        -A "$root\assets" --java "$build\gen" --min-sdk-version 31 --target-sdk-version 36 `
        --version-code 1 --version-name 0.1 "$build\res.zip"
}

$sources = Get-ChildItem -Recurse -Filter *.java "$root\src", "$build\gen" | ForEach-Object { $_.FullName }
Invoke-Step 'javac' {
    & "$env:JAVA_HOME\bin\javac.exe" -source 8 -target 8 -bootclasspath "$androidJar;$bt\core-lambda-stubs.jar" `
        -classpath $xposedJar -Xlint:-options -encoding UTF-8 -d "$build\classes" $sources
}

$classes = Get-ChildItem -Recurse -Filter *.class "$build\classes" | ForEach-Object { $_.FullName }
Invoke-Step 'd8' {
    & "$bt\d8.bat" --release --min-api 31 --lib $androidJar --classpath $xposedJar --output "$build\dex" $classes
}

Copy-Item "$build\app-res.apk" "$build\app-unaligned.apk"
Push-Location "$build\dex"
try {
    Invoke-Step 'aapt add classes.dex' { & "$bt\aapt.exe" add "$build\app-unaligned.apk" classes.dex }
} finally {
    Pop-Location
}

Invoke-Step 'zipalign' { & "$bt\zipalign.exe" -f -p 4 "$build\app-unaligned.apk" "$build\app-aligned.apk" }

$ks = Join-Path $root 'vboostfix.keystore'
if (-not (Test-Path $ks)) {
    Invoke-Step 'keytool' {
        & "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -keystore $ks -alias vboostfix -keyalg RSA -keysize 2048 `
            -validity 10000 -storepass android -keypass android -dname "CN=VBoostFix"
    }
}

Invoke-Step 'apksigner sign' {
    & "$bt\apksigner.bat" sign --ks $ks --ks-key-alias vboostfix --ks-pass pass:android --key-pass pass:android `
        --out "$build\VBoostFix.apk" "$build\app-aligned.apk"
}
Invoke-Step 'apksigner verify' { & "$bt\apksigner.bat" verify --verbose "$build\VBoostFix.apk" }

Write-Host "APK listo: $build\VBoostFix.apk"
