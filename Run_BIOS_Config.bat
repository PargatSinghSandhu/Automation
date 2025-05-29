@echo off
:: Check for admin rights 
net session >nul 2>&1
if %errorLevel% neq 0
(
	echo Requesting admin privileges...
	powershell -Command "Start Process '%~f0' -Verb runAs"
	exit /b
)
::Run PowerShell script from same folder
powershell.exe -ExecutionPolicy Bypass -File "%~dp0ApplyDellBIOSConfig.ps1"
pause