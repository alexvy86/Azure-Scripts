<#
.SYNOPSIS

Script to perform basic management operations (Start, Stop, Restart) on a VM.

.DESCRIPTION

The script can be passed all the necessary parameters to specify a Subscription, VM, and operation to be performed. If some are missing, it will show the list of available options (for subscriptions, then VMs, then operations) and prompt the user to select one. It assumes that the user already executed the Login-AzureRmAccount cmdlet.

.PARAMETER SubscriptionId

The ID of the subscription that contains the VM to be managed.

.PARAMETER VmRgName

The name of the Resource Group that contains the VM to be managed.

.PARAMETER VmName

The name of the VM to be managed.

.PARAMETER Operation

The operation to be performed.

.EXAMPLE

.\ManageVmState

This will start the script and have it prompt the user for all the necessary information

.EXAMPLE

.\ManageVmState -SubscriptionId "########-####-####-####-############" -VmName myVM -VmRgName myRGName

This automatically selects a particular VM in a particular subscription, so the user would only be prompted for the operation to perform.
#>
[CmdletBinding()]
Param (
    [String]
    $SubscriptionId,

    [String]
    $VmRgName,

    [String]
    $VmName,
    
    [ValidateSet(“Start”,”Stop”,”Restart”)]
    [String]
    $Operation
)

function GetIndex($Array) {
    $index = $Array.length 
    do {
        $index = [int](Read-Host "--> ")
    } while ($index -ge $Array.length)
    return $index
}

function FormatVm($VM) {
    $VMStatus = ($VM | Get-AzureRmVM -Status).Statuses[1].DisplayStatus 3>$null
    return "$($VM.Name) (RG: $($VM.ResourceGroupName), Status: $vmStatus)"
}

if (-not $SubscriptionId) {
    $all_subscriptions = Get-AzureRmSubscription

    Write-Host "SELECT A SUBSCRIPTION" -ForegroundColor Cyan
    $all_subscriptions |% { $i = 0 } { Write-Host "$i - $($_.SubscriptionName) ($($_.SubscriptionId))"; $i++ } 

    $subscription_index = GetIndex -Array $all_subscriptions
    $SubscriptionId = $all_subscriptions[$subscription_index].SubscriptionId
}

$which_subscription = Get-AzureRmSubscription -SubscriptionId $SubscriptionId
$which_subscription | Select-AzureRmSubscription
Write-Host "Working on subscription " -NoNewline
Write-Host "$($which_subscription.SubscriptionName) ($($which_subscription.SubscriptionId))" -ForegroundColor Green

if (-not $VmName -or -not $VmRgName) {
    $all_vms = Get-AzureRmVM 3>$null
    
    Write-Host "SELECT A VM" -ForegroundColor Cyan
    $all_vms |% { $i = 0 } { Write-Host "$i - $(FormatVm -VM $_)"; $i++ }

    $vm_index = GetIndex -Array $all_vms
    $VmName   = $all_vms[$vm_index].Name
    $VmRgName = $all_vms[$vm_index].ResourceGroupName
}

$which_vm = Get-AzureRmVM -Name $VmName -ResourceGroupName $VmRgName 3>$null
Write-Host "Working on VM " -NoNewline
Write-Host (FormatVM -VM $which_vm) -ForegroundColor Green

if (-not $Operation) {
    Write-Host "SELECT A STATUS" -ForegroundColor Cyan
    $operations = @("Start", "Stop", "Restart")
    $operations |% { $i = 0 } { Write-Host "$i - $_"; $i++ }
    $operation_index = GetIndex -Array $operations
    $Operation = $operations[$operation_index]
}

switch ($Operation ){
    "Start"   { Write-Host "Starting VM..."; $which_vm | Start-AzureRmVm }
    "Stop"    { Write-Host "Stopping VM..."; $which_vm | Stop-AzureRmVm }
    "Restart" { Write-Host "Restarting VM..."; $which_vm | Restart-AzureRmVM }
}
