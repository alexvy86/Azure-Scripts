<#
.SYNOPSIS

Script to copy a blob from one subscription to another

.DESCRIPTION

This script expects the information for a source Subscription, StorageAccount (Resource Group and Name), Container and Blob, and a destination Subscription, Storage Account (Resource Group and Name) and Container, in order to copy the blob from source to destination environments. It will prompt for credentials for each environment, and create the container in the destination one if it doesn't exist yet. It will not create the Storage Account. Once the copy starts, it will display a dialog that shows the progress of the copy operation. The copied blob will have the same name as the source one.

.PARAMETER Source_SubscriptionId

The ID of the subscription that contains the blob to be copied.

.PARAMETER Source_ResourceGroup

The name of the Resource Group of the Storage Account that contains the blob to be copied.

.PARAMETER Source_StorageAccount

The name of the Storage Account that contains the blob to be copied.

.PARAMETER Blob

The name of the blob to be copied

.PARAMETER Dest_SubscriptionId

The ID of the subscription that should receive the copied blob.

.PARAMETER Dest_ResourceGroup

The name of the Resource Group of the Storage Account that will receive the copied blob.

.PARAMETER Dest_StorageAccount

The name of the Storage Account that will receive the copied blob.
#>
[CmdletBinding()]
Param (
    # Source environment parameters
    [String][Parameter(Mandatory=$true)]
    $Source_SubscriptionID,
    [String][Parameter(Mandatory=$true)]
    $Source_ResourceGroup,
    [String][Parameter(Mandatory=$true)]
    $Source_StorageAccount,
    [String][Parameter(Mandatory=$true)]
    $Source_Container,
    [String][Parameter(Mandatory=$true)]
    $Blob,

    # Destination environment parameters
    [String][Parameter(Mandatory=$true)]
    $Dest_SubscriptionID,
    [String][Parameter(Mandatory=$true)]
    $Dest_ResourceGroup,
    [String][Parameter(Mandatory=$true)]
    $Dest_StorageAccount,
    [String][Parameter(Mandatory=$true)]
    $Dest_Container
)

#region GET CREDENTIALS

$Source_cred = Get-Credential -Message "Input credentials with access to the SOURCE subscription"
$Dest_cred = Get-Credential -Message "Input credentials with access to the DESTINATION subscription"

#endregion

#region PREPARE DESTINATION ENVIRONMENT

#region Login and get reference to the target Storage Account

Login-AzureRmAccount -SubscriptionId $Dest_SubscriptionID -Credential $Dest_cred
$Dest_SA = Get-AzureRmStorageAccount -Name $Dest_StorageAccount -ResourceGroupName $Dest_ResourceGroup

#endregion

#region Create Dest blob container if it doesn't exist

do {
    $StorageContainer = Get-AzureStorageContainer -Context $Dest_SA.Context | Where { $_.Name -eq $Dest_Container }
    if ($StorageContainer -eq $null) {
        New-AzureStorageContainer -Name $Dest_Container -Permission Blob -Context $Dest_SA.Context
    }
} while ($StorageContainer -eq $null)

#endregion

#endregion

#region START COPY FROM SOURCE ENVIRONMENT

#region Login and get reference to the source Storage Account

Login-AzureRmAccount -SubscriptionId $Source_SubscriptionID -Credential $Source_cred
$Source_SA = Get-AzureRmStorageAccount -Name $Source_StorageAccount -ResourceGroupName $Source_ResourceGroup

#endregion

#region Copy blob and monitor progress

Start-AzureStorageBlobCopy -SrcBlob $Blob `
                           -SrcContainer $Source_Container `
                           -SrcContext $Source_SA.Context `
                           -DestBlob $Blob `
                           -DestContainer $Dest_Container `
                           -DestContext $Dest_SA.Context

Get-AzureStorageBlobCopyState -Blob $Blob -Container $Dest_Container -Context $Dest_SA.Context -WaitForComplete

#endregion

#endregion