# By pass execution policy for this specific session only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Set the expected installer on USB
$usbDrive = Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DriveType -eq 2 } 
$installerPath = "$($usbDrive.DeviceID)\Command_Configure.msi"  
$dcuInstaller = "$($usbDrive.DeviceID)\Dell-Command-Update-Application.exe"

# Set the final paths
$cctkPath = "C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe"
$dcuPath = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"

# Step 1: Install Dell Command | Configure if not present 
if (-not (Test-Path $cctkPath)) {
    Write-Host "`n[INFO] Dell Command | Configure not found. Installing..."
    if (Test-Path $installerPath) {
        Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[Error] Command_Configure.msi not found at $installerPath. Aborting..."
        exit 1
    }
} 

# Step 2: Confirm cctk exists
if (-not (Test-Path $cctkPath)) {
    Write-Host "[ERROR] cctk.exe not found after installation. Aborting..."
    exit 1
}

# Step 3: Detect device type
$laptopTypes = @(8,9,10,14)
$chassisType = (Get-WmiObject -Class Win32_SystemEnclosure).ChassisTypes

if ($laptopTypes -contains $chassisType) {
    Write-Host "`n[INFO] Laptop detected - no additional BIOS settings required."
} else {
    Write-Host "`n[INFO] Desktop detected - applying desktop BIOS settings..."
    Start-Process -FilePath $cctkPath -ArgumentList "--AcPower=On" -Wait 
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOn=Everyday" -Wait 
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOnHr=0" -Wait
    Start-Process -FilePath $cctkPath -ArgumentList "--AutoOnMn=0" -Wait
}  

Write-Host "`nBIOS setting applied successfully. Please reboot for changes to take effect."

# Dell Command | Update installation if not present
if (-not (Test-Path $dcuPath)) {
    Write-Host "`n[INFO] Dell Command Update not found. Installing..."
    if (Test-Path $dcuInstaller) {
        Start-Process -FilePath $dcuInstaller -ArgumentList "/silent /norestart" -Wait
        Start-Sleep -Seconds 5
    } else {
        Write-Host "[ERROR] Dell Command Update installer not found at $dcuInstaller"
    }
}

# Check again if installed now
if (Test-Path $dcuPath) {
    Write-Host "`n[INFO] Dell Command Update found. Running updates..."
    Start-Process -FilePath $dcuPath -ArgumentList "/applyUpdates -silent -reboot=disable" -Wait
    Write-Host "[INFO] Dell Command Update completed."
} else {
    Write-Host "`n[ERROR] Dell Command Update CLI still not found at: $dcuPath"
}

# Windows updates
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
}
Import-Module PSWindowsUpdate

# Run Windows Updates
Get-WindowsUpdate -AcceptAll -Install -AutoReboot
