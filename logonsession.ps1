Function ExtractDomainlessUserName {
    param(
        [String]$UserName
    )
    $UserName -match '^\w+\\(.+)' | Out-Null
    $user = $UserName
    if ($Matches) { $user = $Matches[1] }
    return $user
}

Function GetSessionLockTime {
    param(
        $Comp
    )
    # Get time of session lock.
    $locktime = $null
    try {
        $locktimes = Invoke-Command -ComputerName $Comp.__SERVER -ScriptBlock {Get-EventLog Security -InstanceId 4800,4801 -ErrorAction SilentlyContinue}
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
    $online = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
    if (-not $online) { throw "Computer $ComputerName is not on." }

    $comp = Get-WmiObject -ComputerName $ComputerName -Class Win32_ComputerSystem
    $os = Get-WmiObject -ComputerName $ComputerName -Class Win32_OperatingSystem

    if ($comp.UserName) {
        $locked = if (Get-Process -Name LogonUI -ComputerName $ComputerName -ErrorAction SilentlyContinue) {$true} else {$false}
    } else {
        $locked = $false
    }

    $locktime = GetSessionLockTime $comp

    $session = New-Object -TypeName PSCustomObject
    $session | Add-Member -MemberType NoteProperty -Name ComputerName -Value $comp.__SERVER
    $session | Add-Member -MemberType NoteProperty -Name UserName -Value $comp.UserName
    $session | Add-Member -MemberType NoteProperty -Name Locked -Value $locked
    $session | Add-Member -MemberType NoteProperty -Name LockTime -Value $locktime

    return $session
}

if ($args) { LogonSessionFactory $args[0] } else { LogonSessionFactory }