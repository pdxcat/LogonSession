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
        $locktimes,
        $ts
    )
    if ($locktimes) {
        $logonuser = ExtractDomainlessUserName $ts.UserName
        $userlocktimes = $locktimes | Sort-Object TimeGenerated | Where-Object { (ExtractDomainlessUserName ($_.ReplacementStrings[1]) -like $logonuser) -and ($_.TimeGenerated -gt $ts.LoginTime) }
        if ($userlocktimes) {
            if ($userlocktimes[0].InstanceId -eq 4800) {
                    $locktime = Get-Date $locktimes[0].TimeGenerated
            } else {
                Write-Debug "Latest lock event is an unlock."
            }
        }
    }
    return $locktime
}

Function GetLockTimes {
    param(
        [String]$ComputerName
    )
    AssertIsOnline $ComputerName

    # Get time of session lock.
    try {
        $locktimes = Invoke-Command -ComputerName $ComputerName -ScriptBlock {Get-EventLog Security -InstanceId 4800,4801 -ErrorAction SilentlyContinue}
    } catch {
        Write-Warning "Unable to get session lock times from computer $ComputerName."
    }
    return $locktimes
}

Function LogonSessionFactory {
    param(
        [String]$ComputerName = $env:COMPUTERNAME
    )
    AssertIsOnline $ComputerName
    $tsSessions = Get-TSSession -ComputerName $ComputerName | Where-Object { $_.UserName -ne '' }
    $locktimes = GetLockTimes $ComputerName
    foreach ($ts in $tsSessions) {
        $locktime = GetSessionLockTime $locktimes $ts
        $ts | Add-Member -MemberType NoteProperty -Name LockTime -Value $locktime
        $ts | Add-Member -MemberType ScriptMethod -Name Disconnect -Value {Import-Module PSTerminalServices;Get-TSSession -ComputerName $($this.ComputerName) -UserName $($this.UserName) | Disconnect-TSSession -Force} -Force
        $ts | Add-Member -MemberType ScriptMethod -Name Logoff -Value {Import-Module PSTerminalServices;Get-TSSession -ComputerName $($this.ComputerName) -UserName $($this.UserName) | Stop-TSSession -Force} -Force
        if (($ts.WindowStationName -eq 'Console') -and ($ts.ConnectionState -eq 'Active')) {
            $locked = if (Get-Process -Name LogonUI -ComputerName $ComputerName -ErrorAction SilentlyContinue) {$true} else {$false}
        }
        $ts | Add-Member -MemberType NoteProperty -Name Locked -Value $locked # Intentionally null for disconnected sessions
    }
    return $tsSessions
}

if ($args) { LogonSessionFactory $args[0] } else { LogonSessionFactory }
