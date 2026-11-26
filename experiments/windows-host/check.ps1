param(
    [Parameter(Mandatory)]
    [ValidateSet('AMD64', 'ARM64')]
    [string]$Architecture
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

enum WindowsMachine {
    AMD64 = 0x8664
    ARM64 = 0xAA64
}
$machine = [WindowsMachine]$Architecture
$msvcArch = if ($machine -eq [WindowsMachine]::AMD64) { 'x64' } else { 'arm64' }
$devArch = if ($machine -eq [WindowsMachine]::AMD64) { 'amd64' } else { 'arm64' }
$component = if ($machine -eq [WindowsMachine]::AMD64) { 'x86.x64' } else { 'ARM64' }
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$out = Join-Path $root "dist/windows-host/$Architecture"
$dllName = 'moxi-counter.dll'
$symbol = 'moxi_mobile_increment'

function Invoke-Checked([string]$Tool, [string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool failed with exit code $LASTEXITCODE" }
}

if ($env:RUNNER_OS -ne 'Windows' -or $env:RUNNER_ARCH -ne $msvcArch) {
    throw "Expected a native Windows $Architecture runner; got $env:RUNNER_OS/$env:RUNNER_ARCH"
}
Write-Output "RUNNER: Windows $Architecture"
Invoke-Checked python @("$PSScriptRoot/inspect_artifacts.py", $Architecture, $out)

# Use the image's MSVC and SDK; install nothing and do not cross-compile the caller.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = Invoke-Checked $vswhere @('-latest', '-products', '*', '-requires',
    "Microsoft.VisualStudio.Component.VC.Tools.$component", '-property', 'installationPath')
if (-not $vs) { throw "No MSVC installation for $Architecture" }
$devCmd = Join-Path $vs 'Common7/Tools/VsDevCmd.bat'
$environment = Invoke-Checked $env:COMSPEC @('/d', '/s', '/c',
    "call `"$devCmd`" -no_logo -arch=$devArch -host_arch=$devArch >nul && set")
foreach ($line in $environment) {
    if ($line -match '^([^=]+)=(.*)$') { Set-Item "Env:\$($Matches[1])" $Matches[2] }
}
$compiler = (Get-Command cl.exe -CommandType Application).Source
if ($compiler -notlike "*\Host$msvcArch\$msvcArch\cl.exe") {
    throw "MSVC host/target mismatch: $compiler"
}
Write-Output "MSVC: host=$msvcArch target=$msvcArch tools=$env:VCToolsVersion sdk=$env:WindowsSDKVersion"

Push-Location $out
try {
    # Rename only the entry point; all three calls and assertions come from check.c.
    Invoke-Checked $compiler @('/nologo', '/W4', '/WX', '/MT', '/TC', '/c',
        '/Dmain=moxi_counter_check', "$root/experiments/mobile-runtime/check.c", '/Focounter-check.obj')
    Invoke-Checked $compiler @('/nologo', '/W4', '/WX', '/MT',
        "$PSScriptRoot/architecture.c", 'counter-check.obj', 'moxi-counter.lib', 'kernel32.lib',
        '/Fecheck.exe', '/link', '/INCREMENTAL:NO', '/Brepro')

    $exe = [IO.File]::ReadAllBytes((Join-Path $out 'check.exe'))
    $pe = [BitConverter]::ToInt32($exe, 0x3c)
    if ([BitConverter]::ToUInt16($exe, $pe + 4) -ne [int]$machine) {
        throw 'Linked caller PE machine does not match the target'
    }
    Write-Output "CALLER: PE machine=$Architecture"
    $imports = Invoke-Checked dumpbin.exe @('/nologo', '/imports', 'check.exe')
    $importText = $imports -join "`n"
    if ($importText -notmatch "(?m)^\s*$([regex]::Escape($dllName))\s*$" -or
        $importText -notmatch "\b$symbol\b") {
        throw 'Caller does not normally import the scalar function from the expected DLL'
    }
    # Log dependencies without publishing the executable or toolchain.
    Invoke-Checked dumpbin.exe @('/nologo', '/dependents', $dllName)
    Invoke-Checked dumpbin.exe @('/nologo', '/dependents', 'check.exe')
    foreach ($path in @($dllName, 'moxi-counter.lib', 'check.exe')) {
        $hash = (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-Output "SHA256: $hash $path"
    }
    Invoke-Checked '.\check.exe' @()
    Write-Output "PASS: $Architecture native Windows scalar C ABI"
} finally {
    Pop-Location
}
