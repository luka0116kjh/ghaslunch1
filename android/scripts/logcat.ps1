param(
    [switch]$Clear
)

$ErrorActionPreference = "Stop"

$Sdk = "C:\Users\GHAS\AppData\Local\Android\Sdk"
$Adb = Join-Path $Sdk "platform-tools\adb.exe"

$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
$env:Path = "$Sdk\platform-tools;$env:Path"

if (!(Test-Path -LiteralPath $Adb)) {
    throw "adb.exe not found: $Adb"
}

if ($Clear) {
    & $Adb logcat -c
}

& $Adb logcat GHASLunch:D AndroidRuntime:E chromium:W cr_WebViewClient:D '*:S'
