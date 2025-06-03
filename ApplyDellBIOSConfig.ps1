# Bypass execution policy for the current session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Detect USB path dynamically
$usbDrive = Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DriveType -eq 2}
$installerPath = "$($usbDrive.DeviceID)\Command_Configure.msi"
$dcuInstaller = "$($usbDrive.DeviceID)\Dell-Command-Update-Application.exe"

# Set target paths
$cctkPath = "C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe"
$dcuCLIPath = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"

# Step 1: Install Dell Command | Configure if not already installed
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

# Step 2: Confirm installation
if (-not (Test-Path $cctkPath)) {
    Write-Host "[ERROR] cctk.exe not found after installation. Aborting..."
    exit 1
}

# Step 3: Detect device type (laptop or desktop)
$laptopTypes = @(8,9,10,14)
$chassisType = (Get-WmiObject -Class Win32_SystemEnclosure).ChassisTypes

if ($laptopTypes -contains $chassisType) {
    Write-Host "`n[INFO] Laptop detected – no BIOS changes needed."
} else {
    Write-Host "`n[INFO] Desktop detected – applying BIOS settings..."
    Start-Process -FilePath $cctkPath -ArgumentList "--AcPower=On" -Wait
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOn=Everyday" -Wait
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOnHr=0" -Wait
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOnMn=0" -Wait
    Write-Host "`n[INFO] BIOS settings applied. Reboot required for full effect."
}

# Step 4: Install Dell Command | Update if not present
if (-not (Test-Path $dcuCLIPath)) {
    Write-Host "`n[INFO] Dell Command | Update not found. Installing..."
    if (Test-Path $dcuInstaller) {
        Start-Process -FilePath $dcuInstaller -ArgumentList "/s" -Wait
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[ERROR] Dell Command | Update installer not found at: $dcuInstaller"
    }
}

# Step 5: Run Dell Updates using CLI
if (Test-Path $dcuCLIPath) {
    Write-Host "`n[INFO] Running Dell Command Update..."
    Start-Process -FilePath $dcuCLIPath -ArgumentList "/applyUpdates -silent -reboot=disable" -Wait
    Write-Host "[INFO] Dell updates completed."
} else {
    Write-Host "[ERROR] dcu-cli.exe not found. Please check installation."
}

# Step 6: Install and Import PSWindowsUpdate
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
}
Import-Module PSWindowsUpdate

# Step 7: Run Windows Updates
Write-Host "`n[INFO] Checking for Windows Updates..."
Get-WindowsUpdate -AcceptAll -Install -AutoReboot
