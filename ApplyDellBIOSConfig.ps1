# Relaunch the script as admin if not already running as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting as Administrator..."
    Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ====== PASSWORD VERIFICATION BLOCK ======
# Load stored encrypted password (assumes file is next to the script)
$storedPassword = Import-Clixml -Path "$PSScriptRoot\secure_pwd.xml"

# Prompt user
$enteredPassword = Read-Host "Enter BIOS Setup Password to Continue" -AsSecureString

# Convert and compare
$storedPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storedPassword))

$enteredPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($enteredPassword))

if ($storedPlain -ne $enteredPlain) {
    Write-Host "`n[ERROR] Incorrect password. Access denied." -ForegroundColor Red
    exit 1
}


# Dynamically detect USB path
$usbDrive = Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DriveType -eq 2}
$installerPath = "$($usbDrive.DeviceID)\dellcctk\Command_Configure.msi"
$dcuInstaller = "$($usbDrive.DeviceID)\Dell-Command-Update-Application.exe"

# Define final install paths
$cctkPath = "C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe"
$dcuCLIPath = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"

# ========== STEP 1: Install Dell Command | Configure ==========
if (-not (Test-Path $cctkPath)) {
    Write-Host "`n[INFO] Dell Command | Configure not found. Installing..."
    if (Test-Path $installerPath) {
        Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[ERROR] Command_Configure.msi not found at $installerPath. Aborting..."
        exit 1
    }
}

# Confirm installation
if (-not (Test-Path $cctkPath)) {
    Write-Host "[ERROR] cctk.exe not found after installation. Aborting..."
    exit 1
}

# ========== STEP 2: Detect Device Type and Apply BIOS ==========

$chassisType = (Get-WmiObject -Class Win32_SystemEnclosure).ChassisTypes
$laptopTypes = @(8,9,10,14)
 


if ($chassisType | Where-Object { $laptopTypes -contains $_ }) 
{
    Write-Host "`n[INFO] Laptop detected, skipping BIOS changes."
} 
else {
    Write-Host "`n[INFO] Desktop detected, applying BIOS settings..."
    Start-Process -FilePath $cctkPath -ArgumentList "--AcPower=On" -Wait
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOn=Everyday" -Wait
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOnHr=0" -Wait
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOnMn=0" -Wait
    Write-Host "`n[INFO] BIOS settings applied. Reboot required to take effect."
}

# ========== STEP 3: Install Dell Command | Update ==========
if (-not (Test-Path $dcuCLIPath)) {
    Write-Host "`n[INFO] Dell Command | Update not found. Installing..."
    if (Test-Path $dcuInstaller) {
        Start-Process -FilePath $dcuInstaller -ArgumentList "/s" -Wait
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[ERROR] Dell Command | Update installer not found at: $dcuInstaller"
    }
}

# ========== STEP 4: Run Dell Firmware and Driver Updates ==========
if (Test-Path $dcuCLIPath) {
    
    Write-Host "`n[INFO] Running Dell Command Update..."
    Start-Process -FilePath $dcuCLIPath -ArgumentList "/applyUpdates -silent -reboot=disable" -Wait
    Write-Host "[INFO] Dell updates completed."
} else {
    Write-Host "[ERROR] dcu-cli.exe not found. Please check installation."
}

# ========== STEP 5: Install PSWindowsUpdate ==========
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
}
Import-Module PSWindowsUpdate

# ========== STEP 6: Run Windows Updates ==========
Write-Host "`n[INFO] Checking for Windows Updates..."
Get-WindowsUpdate -AcceptAll -Install -AutoReboot

Write-Host "`n[INFO] Windows updates processed."
