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
    if (-not $online) { throw "Computer $ComputerName is not on.`n" }
}

Function GetSessionLockTime {
    param(
        $locktimes,
        $session
    )
    if ($locktimes) {
        $logonuser = ExtractDomainlessUserName $session.UserName
        $userlocktimes = $locktimes | Sort-Object TimeGenerated | Where-Object { (ExtractDomainlessUserName ($_.ReplacementStrings[1]) -like $logonuser) -and ($_.TimeGenerated -gt $session.LoginTime) }
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

Function Get-LogonSession {
    param(
        [String]$ComputerName = $env:COMPUTERNAME
    )
    AssertIsOnline $ComputerName
    $sessions = Get-TSSession -ComputerName $ComputerName | Where-Object { $_.UserName -ne '' } | Sort-Object -Property UserName
    $locktimes = GetLockTimes $ComputerName
    foreach ($session in $sessions) {
        $locktime = GetSessionLockTime $locktimes $session
        $session | Add-Member -MemberType NoteProperty -Name LockTime -Value $locktime
        $session | Add-Member -MemberType ScriptMethod -Name Disconnect -Value {Import-Module PSTerminalServices;Get-TSSession -ComputerName $($this.ComputerName) -UserName $($this.UserName) | Disconnect-TSSession -Force} -Force
        $session | Add-Member -MemberType ScriptMethod -Name Logoff -Value {Import-Module PSTerminalServices;Get-TSSession -ComputerName $($this.ComputerName) -UserName $($this.UserName) | Stop-TSSession -Force} -Force
        $session | Add-Member -MemberType ScriptMethod -Name Logout -Value {$this.Logoff()}
        if (($session.WindowStationName -eq 'Console') -and ($session.ConnectionState -eq 'Active')) {
            $locked = if (Get-Process -Name LogonUI -ComputerName $ComputerName -ErrorAction SilentlyContinue) {$true} else {$false}
        }
        $session | Add-Member -MemberType NoteProperty -Name Locked -Value $locked # Intentionally null for disconnected sessions
    }
    return $sessions
}
