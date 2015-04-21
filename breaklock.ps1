param(
    [String]$ComputerName,
    [Switch]$Force,
    [String]$logpath # location of FWNUA logfiles
)
$ComputerName = $ComputerName.ToUpper()

# Check if computer is up before proceeding.
$online = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
if (-not $online) {
    Write-Error "$ComputerName is down."
} else {
    # Get computer and loggedon user info.
    $comp = Get-WmiObject -ComputerName $ComputerName -Class Win32_ComputerSystem
    $os = Get-WmiObject -ComputerName $ComputerName -Class Win32_OperatingSystem
    $domuser = $comp.UserName

    if ($domuser -eq $null) {
        Write-Host "$ComputerName not loggedon."
    } else {
        # Extract domainless username.
        if ($domuser -Match 'CECS\\(.+)') {
            $user = $matches[1]
        } else {
            $user = $domuser
        }

        # Get recent logons, find most recent one for this computer.
	$logons = @()
        $logons += Import-CSV "${logpath}\${user}.csv" -Header user,logontype,comp,ip,time,domain
        for ($i = $logons.Length-1; $i -ge 0; $i--) {
            # If correct computer name and is a logon, show it.
            if (($logons[$i].comp.toUpper() -eq $ComputerName.toUpper()) -and ($logons[$i].logontype -eq 'on')) {
                $latestLogon = $logons[$i]
                break
            }
        }

        # Parse date.
        $date = get-date -Year $latestLogon.time.Substring(0,4) `
                         -Month $latestLogon.time.Substring(4,2) `
                         -Day $latestLogon.time.Substring(6,2) `
                         -Hour $latestLogon.time.Substring(8,2) `
                         -Minute $latestLogon.time.Substring(10,2)
    
        # Write informative output.
        Write-Host "Computer:  $ComputerName"
        Write-Host "Loggedon user:  $domuser"
        Write-Host "Logon date/time:  $date"
        
        # Ask for confirmation, if needed.
        if (-not $Force) {
            Write-Host "Confirm breaklock (type n to cancel)? " -NoNewLine
            $resp = (Read-Host).toLower()
            if ($resp.StartsWith('n')) {
                Write-Host "Aborted."
            } else {
                $Force = $true
            }
        }
        if ($Force) {
            try {
                $result = $os.Win32Shutdown(4)
            } catch {
                Write-Error "Breaklock failed!"
            }
            if ($result.ReturnValue -eq 0) {
                Write-Host "Lock broken."
            } else {
                Write-Error "Breaklock failed!"
            }
        }
    }
}
