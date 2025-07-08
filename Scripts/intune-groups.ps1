Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
Install-Script -Name Get-WindowsAutoPilotInfo
Get-WindowsAutopilotInfo -AddToGroup "Autopilot Devices" -Online
Disconnect-MGgraph