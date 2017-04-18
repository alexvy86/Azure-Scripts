Register-EngineEvent PowerShell.Exiting -Action { Remove-PSSession $ExchangeOnlineSession; } | Out-Null

$UserCredential = Get-Credential
$ExchangeOnlineSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $ExchangeOnlineSession