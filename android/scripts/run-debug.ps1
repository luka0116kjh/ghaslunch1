param(
    [string]$AvdName = "Pixel_7_Pro",
    [switch]$NoWindow
)

$ErrorActionPreference = "Stop"

$AndroidRoot = Split-Path -Parent $PSScriptRoot
$Sdk = "C:\Users\GHAS\AppData\Local\Android\Sdk"
$Jbr = "C:\Program Files\Android\Android Studio\jbr"
$Adb = Join-Path $Sdk "platform-tools\adb.exe"
$Emulator = Join-Path $Sdk "emulator\emulator.exe"

$env:JAVA_HOME = $Jbr
$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
$env:ANDROID_AVD_HOME = "C:\Users\GHAS\.android\avd"
$env:Path = "$Jbr\bin;$Sdk\platform-tools;$Sdk\emulator;$env:Path"

if (!(Test-Path -LiteralPath $Adb)) {
    throw "adb.exe not found: $Adb"
}
if (!(Test-Path -LiteralPath $Emulator)) {
    throw "emulator.exe not found: $Emulator"
}

$devices = & $Adb devices | Select-String -Pattern "`tdevice$"
if (!$devices) {
    $avds = & $Emulator -list-avds
    if ($avds -notcontains $AvdName) {
        throw "AVD '$AvdName' not found. Available AVDs: $($avds -join ', ')"
    }

    $args = @("-avd", $AvdName, "-netdelay", "none", "-netspeed", "full")
    if ($NoWindow) {
        $args += @("-no-window", "-no-audio", "-no-snapshot", "-gpu", "swiftshader_indirect")
    }

    Start-Process -FilePath $Emulator -ArgumentList $args -WindowStyle Hidden
    & $Adb wait-for-device

    $deadline = (Get-Date).AddMinutes(5)
    do {
        Start-Sleep -Seconds 3
        $bootCompleted = (& $Adb shell getprop sys.boot_completed 2>$null).Trim()
        Write-Host "boot_completed=$bootCompleted"
    } while ($bootCompleted -ne "1" -and (Get-Date) -lt $deadline)

    if ($bootCompleted -ne "1") {
        throw "Emulator did not finish booting within 5 minutes."
    }
}

Push-Location $AndroidRoot
try {
    .\gradlew.bat installDebug
}
finally {
    Pop-Location
}

& $Adb shell monkey -p kr.hs.ghas.ghason -c android.intent.category.LAUNCHER 1
Start-Sleep -Seconds 2
& $Adb shell am start -W -n kr.hs.ghas.ghason/.MainActivity
& $Adb shell dumpsys window | Select-String -Pattern "mCurrentFocus|mFocusedApp"
