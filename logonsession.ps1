#Requires -Module PSTerminalServices

Function ExtractDomainlessUserName {
    param(
        [String]$UserName
    )
    $UserName -match '^\w+\\(.+)' | Out-Null
    $user = $UserName
    if ($Matches) { $user = $Matches[1] }
    return $user
}

Function AssertIsOnline {
    param(
        [String]$ComputerName
    )
    $online = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
    if (-not $online) { throw "Computer $ComputerName is not on." }
}

Function GetSessionLockTime {
    param(
        $Comp
    )
    $ComputerName = $Comp.__SERVER
    AssertIsOnline $ComputerName

    # Get time of session lock.
    $locktime = $null
    try {
        $locktimes = Invoke-Command -ComputerName $ComputerName -ScriptBlock {Get-EventLog Security -InstanceId 4800,4801 -ErrorAction SilentlyContinue}
    } catch {
        Write-Warning "Unable to get session lock times from computer $ComputerName."
    }
    if ($locktimes) {
        if ($locktimes[0].InstanceId -eq 4800) {
            $lockuser = ExtractDomainlessUserName $locktimes[0].ReplacementStrings[1]
            $logonuser = ExtractDomainlessUserName $comp.UserName
            if ($lockuser -like $logonuser) {
                $locktime = Get-Date $locktimes[0].TimeGenerated
            } else {
                Write-Debug "Lockuser ($lockuser) does not match logonuser ($logonuser)"
            }
        } else {
            Write-Debug "Latest lock event is an unlock."
        }
    }
    return $locktime
}

Function LogonSessionFactory {
    param(
        [String]$ComputerName = $env:COMPUTERNAME
    )
    AssertIsOnline $ComputerName

    $comp = Get-WmiObject -ComputerName $ComputerName -Class Win32_ComputerSystem
    $os = Get-WmiObject -ComputerName $ComputerName -Class Win32_OperatingSystem
    $tsSessions = Get-TSSession -ComputerName $ComputerName | Where-Object { $_.UserName -ne '' }

    $logonSessions = @()
    foreach ($ts in $tsSessions) {
        $locktime = GetSessionLockTime $comp

        $session = New-Object -TypeName PSCustomObject
        $session | Add-Member -MemberType NoteProperty -Name ComputerName -Value $comp.__SERVER
        $session | Add-Member -MemberType NoteProperty -Name UserName -Value $ts.UserName
        $session | Add-Member -MemberType NoteProperty -Name Type -Value $ts.WindowStationName
        $session | Add-Member -MemberType NoteProperty -Name LockTime -Value $locktime
        $session | Add-Member -MemberType ScriptMethod -Name Disconnect -Value {Import-Module PSTerminalServices;Get-TSSession -ComputerName $($this.ComputerName) -UserName $($this.UserName) | Disconnect-TSSession -Force}
        $session | Add-Member -MemberType ScriptMethod -Name Logoff -Value {Import-Module PSTerminalServices;Get-TSSession -ComputerName $($this.ComputerName) -UserName $($this.UserName) | Stop-TSSession -Force}
        if ($ts.WindowStationName -eq 'Console') {
            # Console session
            $locked = if (Get-Process -Name LogonUI -ComputerName $ComputerName -ErrorAction SilentlyContinue) {$true} else {$false}
            if ($locked) {
                $session | Add-Member -MemberType NoteProperty -Name Status -Value "Locked"
            } else {
                $session | Add-Member -MemberType NoteProperty -Name Status -Value $ts.ConnectionState
            }
        } else {
            # RDP or Switched-User session
            $session | Add-Member -MemberType NoteProperty -Name Status -Value $ts.ConnectionState
        }
        $logonSessions += $session
    }
    return $logonSessions
}

if ($args) { LogonSessionFactory $args[0] } else { LogonSessionFactory }
