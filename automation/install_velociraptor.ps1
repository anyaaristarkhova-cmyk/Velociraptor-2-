
param(
    [string]$MsiPath = "$PSScriptRoot\velociraptor_custom.msi"
)

$ErrorActionPreference = "Stop"
$serviceName = "Velociraptor"
$changes = 0

Write-Host "Checking Velociraptor..."

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Host "Agent is missing."

    if (-not (Test-Path -LiteralPath $MsiPath -PathType Leaf)) {
        throw "Installer MSI not found: $MsiPath"
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $isAdmin) {
        throw "Administrator privileges required."
    }

    $msi = (Resolve-Path -LiteralPath $MsiPath).Path

    $process = Start-Process msiexec.exe `
        -ArgumentList "/i `"$msi`" /qn /norestart" `
        -Wait -PassThru

    if ($process.ExitCode -notin @(0, 3010)) {
        throw "MSI failed: $($process.ExitCode)"
    }

    $changes++
}

$service = Get-CimInstance Win32_Service -Filter "Name='Velociraptor'"

if (-not $service) {
    throw "Velociraptor service not found."
}

if ($service.StartMode -ne "Auto") {
    Set-Service -Name $serviceName -StartupType Automatic
    $changes++
}

if ($service.State -ne "Running") {
    Start-Service -Name $serviceName
    $changes++
}

$service = Get-CimInstance Win32_Service -Filter "Name='Velociraptor'"

Write-Host "Status: $($service.State)"
Write-Host "Startup: $($service.StartMode)"
Write-Host "CHANGED=$changes"

