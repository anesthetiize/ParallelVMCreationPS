cls
#Variables set up

Import-AzureRmContext -Path "C:\AzureProfile\AzureRmProfileContext.ctx"
Select-AzureRmSubscription -SubscriptionId c7f5ad6e-f463-4f43-8ee0-08b8814de39f


$Global:VMSize = "Standard_DS3"
$Global:ResourceGroupName = "ThreadPool"
$Global:StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName ThreadPool -Name threadstorageaccount
$Global:VNet = Get-AzureRmVirtualNetwork -ResourceGroupName ThreadPool -Name ThreadVNet
$Global:Location = $Global:StorageAccount.Location


#VM Names Array setup.
######################
$Num = Read-Host "Number of VMs?"

$MainVMName = Read-Host "Common HostName of VMs?"
$global:namelist = ($MainVMName + "1"), ($MainVMName + "2")
$global:i = 3

if($Num -le 2){

    #TO-DO Validate just 2 or less VMs.

}
else{

    while($global:i -le $Num ){

    $global:namelist += $MainVMName + $i
    $i += 1

    }

}


#Creation Code
##############

$Creds = Get-Credential -Message "Enter the Credentials to the Virtual Machines"


workflow threading{

    param($Credentials, $NameList, $Location, $VMSize, $resourceGroupName, $VNet, $StorageAccount)

    #InlineScript{Write-Host "CREATING [$ComputerName] Virtual Machine" -ForegroundColor Red -BackgroundColor Black}

    foreach -parallel ($hostname in $NameList){
        
        Import-AzureRmContext -Path "C:\AzureProfile\AzureRmProfileContext.ctx"
        Select-AzureRmSubscription -SubscriptionId c7f5ad6e-f463-4f43-8ee0-08b8814de39f

        $OSDiskName = $hostname + "osDisk"

        #WARNING:::::HARDCODED SKU
        Write-Output "Creating VIP [$hostname _VIP]"
        $PIp = New-AzureRmPublicIpAddress -Name ($hostname + "_VIP") -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic

        Write-Output "Creating NIC [$hostname _NIC]"
        $Interfaces = New-AzureRmNetworkInterface -Name ($hostname + "_NIC") -ResourceGroupName $resourceGroupName -Location $Location -SubnetId $VNet.Subnets[0].Id -PublicIpAddressId $PIp.Id
        $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
        Write-Output "Creating [$hostname] VM"

        ## Create the VM in Azure
        #The parameter -VM cannot be passed as an object variable due to Workflow limitations.

        New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $Location -VM (Set-AzureRmVMOSDisk -VM (Add-AzureRmVMNetworkInterface -VM (Set-AzureRmVMSourceImage -VM (Set-AzureRmVMOperatingSystem -VM (New-AzureRmVMConfig -VMName $hostname -VMSize $VMSize) -Windows -ComputerName $hostname -Credential $Credentials -ProvisionVMAgent -EnableAutoUpdate) -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version "latest") -Id $Interfaces.Id) -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage)
    
    }

}

threading -Credentials $creds -NameList $namelist -Location $Location -VMSize $VMSize -resourceGroupName $ResourceGroupName -VNet $VNet -StorageAccount $StorageAccount
