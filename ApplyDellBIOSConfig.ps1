# Import the module for windows updates
Import-Module PSWindowsUpdate


# By pass execution policy for this specific session only. NOTE: This is only for this session, so no security risk system wide, and -Force only supresses the confirmation prompt

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

#set the expected installer on USB
$usbDrive = Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DriveType -eq 2 } # Dynamically taking the USB path

$installerPath = "$($usbDrive.DeviceID)\Command_Configure.msi"  

# Set the final cctk path
$cctkPath = "C:\Program Files (x86)\Dell\Command Configure\X86_64\cctk.exe"

# Step 1: Install Dell Command | Configure if not present 
if(-not (Test-Path $cctkPath))
{
	Write-Host "`n[INFO] Dell Command | Configure not found. Installing..."

	if(Test-Path $installerPath)
	{
	   Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait
	   Start-Sleep -Seconds 5
	}
	else
	{
	   Write-Host "[Error] Command_Configure.msi not found at $installerPath. Aborting..."
	   exit 1
	}
} 

#Step 2: Confirm cctk exists now

if(-not(Test-Path $cctkPath))
{
	Write-Host "[ERROR] cctk.exe not found after installation. Aborting..."
	exit 1
}

#Step 3: Detect device type
$laptopTypes = @(8,9,10,14)
$chassisType = (Get-WmiObject -Class Win32_SystemEnclosure).ChassisTypes

if($laptopTypes -contains $chassisType)
{
	Write-Host "`n[INFO] Laptop detected - no additional BIOS settings required."
}
else 
 {
	Write-Host "`n[INFO] Desktop detected - applying desktop BIOS settings..."
	Start-Process -FilePath $cctkPath -ArgumentList "--AcPower=On" -Wait 
	Start-Process -FilePath $cctkPath -ArgumentList "--AutoOn=Everyday" -Wait 
	Start-Process -FilePath $cctkPath -ArgumentList "--AutoOnHr=0" -Wait
	Start-Process -FilePath $cctkPath -ArgumentList "--AutoOnMn=0" -Wait
}  

Write-Host "`n BIOS setting applied successfully. Please reboot the changes to take effect."

# Local admin configuration 

#prompt user to enter password securely

$securePassword = Read-Host "Enter the password for NursingIT" -AsSecureString

#Set password for the user 
$adminUser = "NursingIT"

if(Get-LocalUser -Name $adminUser -ErrorAction SilentlyContinue)
{
	Write-Host "`n[INFO] Updating password for $adminUser..."
	Set-LocalUser -Name $adminUser -Password $securePassword 

	#set password to never expire
	Write-Host "[INFO] Setting password to never expire..."
	
	
	try
	{
		$user = Get-LocalUser -Name $adminUser
		$user.PasswordNeverExpires = $true
		$user | Set-LocalUser
	}
	catch
	{
		Write-Host "[INFO] Failed to set password to never expire: $_"
	}
	
	#Add to administrator group (if not already a member) 
	$group = "Administrators"
	try
	{	
		$groupMembers = Get-LocalGroupMember -Group $group -ErrorAction Stop
		$isMember = $groupMembers | Where-Object {$_.Name -like "*$adminUser"}

		if(-not $isMember)
		{
		 Write-Host "[INFO] Adding $adminUser to Administrator group..."
		 Add-LocalGroupMember -Group $group -Member $adminUser
	        }

		else
	       {
		 Write-Host "[INFO] $adminUser is already in the Administrators group."
	       }
	}
	catch
	{ 
             Write-Host "[WARNING] Could not verify or add group membership: $_"
	}

	
}
else
{
		Write-Host "[ERROR] Local user $adminUser not found. Please check the user account name."
}

Write-Host "`nScript completed! Please reboot if BIOS settings were changed." 

#Updates and Installs 

$dcuPath = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe..."

#Check if it is installed 

if(Test-Path $dcuPath)
{
	Write-Host "`n[INFO] Dell Command Update found. Running updates..."

	#Run silent update (no reboot)
	Start-Process -FilePath $dcuPath -ArgumentList "/applyUpdates -silent -reboot=disable" Wait
	
	Write-Host "[INFO] Dell Command Update completed."
}
else
{
	Wtite-Host "`n[ERROR] Dell Command Update CLI not found at: $dcuPath"
	Write-Host "[ACTION] Please install Dell Command | Update manually or include in the base image."
}



#Scan and install available windows updates 
Get-WindowsUpdate -AcceptAll -Install -AutoReboot
