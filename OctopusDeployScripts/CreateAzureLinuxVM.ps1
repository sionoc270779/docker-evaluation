# Variables automatically populated by Octopus Variables - currently placeholders
<#
$vmName
$vmSize
$azureResourceGroup
$azureProfilePath
$azureLocation
$azureVirtualNetwork
$azureSubNet
$azureStorageAccountName
$skuName
$azureContainerName
$osDiskName
$sshKeyPath
#>
	
# Default Variables
$vmUpAndRunning = $False
$userName='azuretestuser'
$securePassword = ConvertTo-SecureString " " -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($userName, $securePassword)

# Check existance of the VM - if not we need to create
$azureVM = Get-AzureVM -ServiceName $vmName
if (($azureVM.Count -eq 0) -OR ($azureVM -eq $Null) -Or ($azureVM -eq ""))
{
	Write-Output "Azure VM - ${vmName} doesn't Exists : Creating"
	
	# Check if resource group exists if not create it
	$rg = Get-AzureRmResourceGroup -Name $azureResourceGroup -ErrorAction SilentlyContinue
	if ($rg -eq $null)
	{
		New-AzureRmResourceGroup -Name $azureResourceGroup -Location $azureLocation
	}
	
	# Create a new storage account
	$storageAccount = New-AzureRMStorageAccount -Location $azureLocation -ResourceGroupName $azureResourceGroup -Type $skuName -Name $azureStorageAccountName
	Set-AzureRmCurrentStorageAccount -StorageAccountName $azureStorageAccountName -ResourceGroupName $azureResourceGroup

	# Create a storage container to store the virtual machine image
	$container = New-AzureStorageContainer -Name $azureContainerName -Permission Blob 

	# Create a subnet configuration
	$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $azureSubNet -AddressPrefix 192.168.1.0/24

	# Create a virtual network
	$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $azureResourceGroup -Location $azureLocation -Name $azureVirtualNetwork -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

	# Create a public IP address and specify a DNS name
	$pip = New-AzureRmPublicIpAddress -ResourceGroupName $azureResourceGroup -Location $azureLocation -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "sionpublicdns$(Get-Random)"
	
	# Create an inbound network security group rule for port 22 (ssh)
	$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name "sionTestNetworkSecurityGroupRuleSSH"  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow

	# Create an inbound network security group rule for port 80
	$nsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name "sionTestNetworkSecurityGroupRuleWWW"  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow

	# Create a network security group
	$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $azureResourceGroup -Location $azureLocation -Name "sionTestNetworkSecurityGroup" -SecurityRules $nsgRuleSSH,$nsgRuleWeb
	
	# Create a virtual network card and associate it with public IP address and NSG
	$nic = New-AzureRmNetworkInterface -Name sionTestNic -ResourceGroupName $azureResourceGroup -Location $azureLocation -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id 
	
	# Setup Blob storage for the OS disk
	$osDiskUri = '{0}vhds/{1}-{2}.vhd' -f $storageAccount.PrimaryEndpoints.Blob.ToString(),$vmName.ToLower(),$osDiskName
  
	# Create the virtual machine configuration object
	$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize | `
				Set-AzureRmVMOperatingSystem -Linux -ComputerName $vmName -Credential $cred | `
				Set-AzureRmVMSourceImage -PublisherName Canonical -Offer "UbuntuServer" -Skus "16.04-LTS" -Version "latest" | `
				Set-AzureRmVMOSDisk -Name $osDiskName -VhdUri $OsDiskUri -CreateOption FromImage | `
				Add-AzureRmVMNetworkInterface -Id $nic.Id 
	
	# Configure SSH Keys
	$sshPublicKey = Get-Content $sshKeyPath #"$env:USERPROFILE\.ssh\id_rsa.pub"
	Add-AzureRmVMSshPublicKey -VM $vmConfig -KeyData $sshPublicKey -Path "/home/${userName}/.ssh/authorized_keys"
	
	# Create the virtual machine.
	New-AzureRmVM -ResourceGroupName $azureResourceGroup -Location $azureLocation -VM $vmConfig 
	
	# Install Docker and run container
	$publicSettings = '{"docker": {"port": "2375"},"compose": {"web": {"image": "nginx","ports": ["80:80"]}}}'

	Set-AzureRmVMExtension -ExtensionName "Docker" -ResourceGroupName $azureResourceGroup -VMName $vmName -Publisher "Microsoft.Azure.Extensions" -ExtensionType "DockerExtension" -TypeHandlerVersion 1.0 -SettingString $publicSettings -Location $azureLocation
	
	# Ensure the VM is up and running
	While ($vmUpAndRunning -eq $False)
	{
	}
}
else
{
	Write-Output "Azure VM - ${vmName} Already Exists : Skipping"
}