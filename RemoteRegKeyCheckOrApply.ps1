<#
.SYNOPSIS

Script to check registry key values in a list of remote servers, and optionally apply new values.

.DESCRIPTION

The script will establish remote sessions to a list of specified servers (or the Domain Controllers in Active Directory if no list is specified), retrieve the current values of a specified list of registry keys, and store the results for each server in a user-defined UNC path. Registry keys that cannot be found are stored in a "MissingKeys" file, and errors are reported to an "ErrorsFile". If the ApplySettings switch is used, the script will attempt to write new values to the registry keys on all servers.

.PARAMETER ApplySettings

If specified, the script will try to write new values from the input CSV file to the registry keys in all the target servers.

.PARAMETER InputFile

Path to the file that contains the registry keys to be queried/updated. If this is not specified, the script will look for a "regkeys.csv" file in the current directory. The file should have the following columns (including a headers row with these names):
- SettingName: friendly name of the setting (usually as defined in GPO)
- UIPath: "path" to the setting in the GPO management console
- Key: "path" to the setting in the registry
- Value: "name" of the setting in the registry (what's shown in the right panel in RegEdit)

In order to apply new values, two more columns are needed:
- Type: the data type (REG_DWORD, REG_SZ, etc)
- Data: the value to be applied

Following is a sample extract (note that <dummy_data> is being used instead of an actual value) from a file, with each line denoted by a *

*SettingName,UIPath,Key,Value,Type,Data
*Allow indexing of encrypted files,Computer Configuration\Administrative Templates\Windows Components\Search\Allow indexing of encrypted files,HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search,AllowIndexingEncryptedStoresOrItems,REG_DWORD,0x0
*Allow members of the Everyone group to run applications that are located in the Program Files folder,Computer Configuration\Windows Settings\Security Settings\Application Control Policies\AppLocker\Executable Rules\Allow members of the Everyone group to run applications that are located in the Program Files folder,HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Exe\921cc481-6e17-4653-8f75-050b80acca20,Value,REG_SZ,<dummy_data>

.PARAMETER ServerList

Path to the file that contains the list of target servers. If not specified, the script will execute against all the Domain Controllers in the domain. The file should list one server name per line and should NOT have a header.

.PARAMETER UNCPath

The UNC path where result files will be stored. E.g. "\\MyServer\My\UNC\path"

.EXAMPLE

.\RemoteRegKeyCheckOrApply.ps1 -InputFile "C:\registry_info.csv" -ServerList "C:\server_list.txt" -UNCPath "C:\results_folder"

This will query the target servers and generate output files for the current values.

.EXAMPLE

.\RemoteRegKeyCheckOrApply.ps1 -InputFile "C:\registry_info.csv" -ServerList "C:\server_list.txt" -UNCPath "C:\results_folder" -ApplySettings

This will first query the target servers, generate output files for the current values, and then try to apply new values from the registry_info.csv file.
#>
[CmdletBinding()]
Param (
    [Switch]
    $ApplySettings,

    [String]
    $InputFile = "regkeys.csv",

    [String]
    $ServerList,

    [Parameter(Mandatory=$true)]
    [String]
    $UNCPath
)

$regkeys = Import-Csv $InputFile

if ($ServerList -eq $null -or $ServerList -eq "") {
    $dc = ADDomainController -filter * | Select-Object Name 
    $computers = $dc.name 
} else {
    $computers = Get-content $ServerList
}

try{
    $sessions = New-PSSession -ComputerName $computers -Authentication Kerberos #-Credential $credentials

    # Always query registry and create output files
    
    Invoke-Command -Session $sessions -ScriptBlock {
    param($ApplySettings,$regkeys,$UNCPath)
    Write-Host "[$($env:COMPUTERNAME)] Querying for registry keys"
        foreach($key in $regkeys)
        {
            #reg query "HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v AppData | findstr /L AppData >> c:\users\mario.alanis\desktop\testreg.csv
            try {
                $line = (reg query $key.Key /v $key.Value | findstr /L $key.Value).Replace("    ",",") 2>> "$UNCPath\$($env:COMPUTERNAME)_Errors.txt"
                "$($key.Key)$line" >> "$UNCPath\$($env:COMPUTERNAME)_ExistingKeys.txt"
            }
            catch {
                "$($key.Key) ! $($key.Value)" >> "$UNCPath\$($env:COMPUTERNAME)_MissingKeys.txt"
            }
        }

        if ($ApplySettings) {
    
            Write-Host "[$($env:COMPUTERNAME)] Applying new registry key values"

            foreach($key in $regkeys)
            {
                #reg add "HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /t REG_EXPAND_SZ /v AppData /d %USERPROFILE%\AppData\Roaming /f
                reg add $key.key /t $key.type /v $key.value /d $key.data 2>> "$UNCPath\$($env:COMPUTERNAME)_Errors.txt"
            }
        }
        Write-Host "[$($env:COMPUTERNAME)] Done with server"
    } -ArgumentList $ApplySettings,$regkeys,$UNCPath
} finally {
    Remove-PSSession $sessions
}