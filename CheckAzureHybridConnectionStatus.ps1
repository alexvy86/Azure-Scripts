# This script looks at the status of the Azure Hybrid Connection service, assuming
# it is installed in the server where this script runs, and if the service is not
# online the script then sends an e-mail notification to a specified list of
# recipients. It can also be configured to restart the Azure Hybrid Connection
# service automatically

$mailserver = "mail.definityfirst.com";
$fromAddress = "noreply@definityfirst.com";
$recipients = @("alex.villarreal@definityfirst.com", "luis.pina@definityfirst.com", "fernando.gutierrez@definityfirst.com");

$RESTART_SERVICE_AUTOMATICALLY = $true;

try {
    $hybridConnection = Get-HybridConnection

    if ($hybridConnection.IsOnline -eq $false) {
        if ($RESTART_SERVICE_AUTOMATICALLY) { Restart-Service -Name HybridConnectionManager; }

        Send-MailMessage `
	        -SmtpServer $mailserver `
            -From $fromAddress `
	        -To $recipients `
	        -Subject "Hybrid Connection in $(HOSTNAME) is offline" `
            -BodyAsHtml @"
The Azure Hybrid Connection in $(HOSTNAME) was found to be offline.<br/>
Uri: $($hybridConnection.Uri)<br/>
IsOnline: $($hybridConnection.IsOnline)<br/>
LastError: $($hybridConnection.LastError)<br/>
<br/>
The service was $(if ($RESTART_SERVICE_AUTOMATICALLY) {""} else {"NOT "})restarted.
"@;
    }
}
catch {
    Send-MailMessage `
	        -SmtpServer $mailserver `
            -From $fromAddress `
	        -To $recipients `
	        -Subject "Could not check the status of the Hybrid Connection in $(HOSTNAME)" `
            -BodyAsHtml @"
An unexpected error occurred while checking the status of the Azure Hybrid Conneciton in $(HOSTNAME), or restarting the service.<br/><br/>
Exception:<br/>
$($_.Exception)
"@
}