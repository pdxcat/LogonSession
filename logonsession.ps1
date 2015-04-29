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

    $session = New-Object -TypeName PSCustomObject
    $session | Add-Member -MemberType NoteProperty -Name ComputerName -Value $comp.__SERVER
    $session | Add-Member -MemberType NoteProperty -Name UserName -Value $comp.UserName
    $session | Add-Member -MemberType NoteProperty -Name Locked -Value $locked

    return $session
}

if ($args) { LogonSessionFactory $args[0] } else { LogonSessionFactory }