Function LogonSessionFactory {
    param(
        [String]$ComputerName = $env:COMPUTERNAME
    )
    $session = New-Object -TypeName PSCustomObject
    $online = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
    if (-not $online) { throw "Computer $ComputerName is not on." }

    $session | Add-Member -MemberType NoteProperty -Name ComputerName -Value $ComputerName.toUpper()

    return $session
}

if ($args) { LogonSessionFactory $args[0] } else { LogonSessionFactory }