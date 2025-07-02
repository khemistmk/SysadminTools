#Requires -RunAsAdministrator
#How To: Quick Setup of OSDCloud
#Drivers: All
#Startup: OSDCloudGUI

Install-Module OSD -Force
Import-Module OSD -Force
New-OSDCloudtemplate
New-OSDCloudworkspace -WorkspacePath C:\OSDCloud
Edit-OSDCloudWinPE -StartOSDCloud "-OSName 'Windows 11 24H2 x64' -OSLanguage en-us -OSEdition Pro -OSActivation Retail -ZTI"
New-OSDCloudiso