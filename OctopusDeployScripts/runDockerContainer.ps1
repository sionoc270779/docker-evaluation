# Variables automatically populated by Octopus Variables - currently placeholders
<#
$vmName
$azureResourceGroup
$azureProfilePath
$pathToComposeFile
$sshPRKeyPath
$sshPRKeyPass
#>

# Default Variables
$userName="azuretestuser"
$composeData = Get-Content $pathToComposeFile

# Select right user profile 
Select-AzureRmProfile -Path $azureProfilePath

# Get Public IP of VM
$ipAddr = $(Get-AzureRmPublicIpAddress -ResourceGroupName $azureResourceGroup | Select IpAddress).IpAddress

# Connect To Machine via SSH (PuTTy)
# Create the compose file
plink -ssh -i $sshPRKeyPath $username@$ipAddr -pw $sshPRKeyPass "rm -f -- docker-compose.yml"

ForEach ($line in $composeData)
{
	$line = $line.Replace("""","\""")
	plink -ssh -i $sshPRKeyPath $username@$ipAddr -pw $sshPRKeyPass "echo '${line}' >> docker-compose.yml"
}

plink -ssh -i $sshPRKeyPath $username@$ipAddr -pw $sshPRKeyPass "docker swarm init;docker stack deploy -c docker-compose.yml port-tutorial"