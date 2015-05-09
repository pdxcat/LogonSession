# LogonSession PowerShell Module
This module allows you to get information about Remote Desktop and Console logon sessions on Windows machines, and to enable you to disconnect users from them and/or log them off.

## Requirements
* The PSTerminalServices PowerShell Module (https://psterminalservices.codeplex.com/)
* PowerShell Remoting (to get the time that a session was locked at the console)

## Usage
```powershell
Import-Module LogonSession
Get-LogonSession -ComputerName [comp]
```

Returns a collection of PowerShell objects which are a slightly modified version of the types that you get from the PSTerminalServices module's Get-TSSession function. You can then look at information about them, or call the `Disconnect()` or `Logoff()`/`Logout()` functions to forcibly disconnect or log off the user.
