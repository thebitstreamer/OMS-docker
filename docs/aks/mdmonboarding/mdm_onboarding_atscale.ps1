﻿<# 
    .DESCRIPTION 
		Adds the Monitoring Metrics Publisher role assignment to the all AKS clusters in specified subscription        
      
	
    .PARAMETER SubscriptionId
        Subscription Id that the AKS cluster is in

#>

param(
	[Parameter(mandatory=$true)]
	[string]$SubscriptionId	
)


# checks the required Powershell modules exist and if not exists, request the user permission to install
$azAccountModule = Get-Module -ListAvailable -Name Az.Accounts
$azAksModule = Get-Module -ListAvailable -Name Az.Aks 
$azResourcesModule = Get-Module -ListAvailable -Name Az.Resources

if (($azAccountModule -eq $null) -or ($azAksModule -eq $null) -or ($azResourcesModule -eq $nul)) {


    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	    Write-Host("Running script as an admin...")
	    Write-Host("")
    } else {
	    Write-Host("Please run the script as an administrator") -ForegroundColor Red
	    Stop-Transcript
	    exit
    }


    $message = "This script will try to install the latest versions of the following Modules : `
			    Az.Resources, Az.Accounts and Az.Aks using the command`
			    `'Install-Module {Insert Module Name} -Repository PSGallery -Force -AllowClobber -ErrorAction Stop -WarningAction Stop'
			    `If you do not have the latest version of these Modules, this troubleshooting script may not run."
    $question = "Do you want to Install the modules and run the script or just run the script?"

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes, Install and run'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Continue without installing the Module'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Quit'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 0)

    switch ($decision) {
	    0 { 

           try {
			    Write-Host("Installing Az.Resources...")
			    Install-Module Az.Resources -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
		    } catch {
			    Write-Host("Close other powershell logins and try installing the latest modules forAz.Accounts in a new powershell window: eg. 'Install-Module Az.Accounts -Repository PSGallery -Force'") -ForegroundColor Red
			    exit
		    }

		    try {
			    Write-Host("Installing Az.Accounts...")
			    Install-Module Az.Accounts -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
		    } catch {
			    Write-Host("Close other powershell logins and try installing the latest modules forAz.Accounts in a new powershell window: eg. 'Install-Module Az.Accounts -Repository PSGallery -Force'") -ForegroundColor Red
			    exit
		    }

		    try {
			    Write-Host("Installing Az.Aks...")
			    Install-Module Az.Aks -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
		    } catch {
			    Write-Host("Close other powershell logins and try installing the latest modules for Az.Aks in a new powershell window: eg. 'Install-Module Az.Aks -Repository PSGallery -Force'") -ForegroundColor Red 
			    exit
		    }	
           
	    }
	    1 {

          try {
			    Import-Module Az.Resources -ErrorAction Stop
		    } catch {
			    Write-Host("Could not import Az.Resources...") -ForegroundColor Red
			    Write-Host("Close other powershell logins and try installing the latest modules for Az.Resources in a new powershell window: eg. 'Install-Module Az.Resources -Repository PSGallery -Force'") -ForegroundColor Red
			    Stop-Transcript
			    exit
		    }

		    try {
			    Import-Module Az.Accounts -ErrorAction Stop
		    } catch {
			    Write-Host("Could not import Az.Accounts...") -ForegroundColor Red
			    Write-Host("Close other powershell logins and try installing the latest modules for Az.Accounts in a new powershell window: eg. 'Install-Module Az.Accounts -Repository PSGallery -Force'") -ForegroundColor Red
			    Stop-Transcript
			    exit
		    }
		    try {
			    Import-Module Az.Aks -ErrorAction Stop
		    } catch {
			    Write-Host("Could not import Az.Aks... Please reinstall this Module") -ForegroundColor Red
			    Stop-Transcript
			    exit
		    }         
	
	    }
	    2 { 
		    Write-Host("")
		    Stop-Transcript
		    exit
	    }
    }
}

try {
	Write-Host("")
	Write-Host("Trying to get the current Az login context...")
	$account = Get-AzContext -ErrorAction Stop
	Write-Host("Successfully fetched current AzContext context...") -ForegroundColor Green
	Write-Host("")
} catch {
	Write-Host("")
	Write-Host("Could not fetch AzContext..." ) -ForegroundColor Red
	Write-Host("")
}


if ($account.Account -eq $null) {
	try {
		Write-Host("Please login...")
		Connect-AzAccount -subscriptionid $SubscriptionId
	} catch {
		Write-Host("")
		Write-Host("Could not select subscription with ID : " + $SubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
		Write-Host("")
		Stop-Transcript
		exit
	}
} else {
	if ($account.Subscription.Id -eq $SubscriptionId) {
		Write-Host("Subscription: $SubscriptionId is already selected. Account details: ")
		$account
	} else {
		try {
			Write-Host("Current Subscription:")
			$account
			Write-Host("Changing to subscription: $SubscriptionId")
			Set-AzContext -SubscriptionId $SubscriptionId
		} catch {
			Write-Host("")
			Write-Host("Could not select subscription with ID : " + $SubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
			Write-Host("")
			Stop-Transcript
			exit
		}
	}
}

#
#   get all the AKS clusters in specified subscription
#
Write-Host("getting all aks clusters in specified subscription ...")
$allClusters = Get-AzAks -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
	Write-Host("")
	Write-Host("Failed to get Aks clusters in specified subscription. Please make sure that you have access to the existing clusters") -ForegroundColor Red
	Write-Host("")
	Stop-Transcript
	exit
}
Write-Host("Successfully got all aks clusters ...") -ForegroundColor Green

$clustersCount = $allClusters.Id.Length

Write-Host("Adding role assignment for the clusters ...")

for($index = 0 ; $index -lt $clustersCount ; $index++) {  

    #
    #  Add Monitoring Metrics Publisher role assignment to the AKS cluster resource
    #

    $servicePrincipalClientId =  $allClusters.ServicePrincipalProfile[$index].ClientId
    $clusterResourceId = $allClusters.Id[$index]
    $clusterName =$allClusters.Name[$index]


    Write-Host("Adding role assignment for the cluster: $clusterResourceId, servicePrincipalClientId: $servicePrincipalClientId ...")

  
    New-AzRoleAssignment -ApplicationId $servicePrincipalClientId -scope $clusterResourceId -RoleDefinitionName "Monitoring Metrics Publisher"  -ErrorVariable assignmentError -ErrorAction SilentlyContinue

    if ($assignmentError) {

       if($assignmentError.Exception -match "role assignment already exists") {
          
          Write-Host("Monitoring Metrics Publisher role assignment already exists on the cluster resource : '" + $clusterName + "'") -ForegroundColor Green 

       } else { 
        
          Write-Host("Failed to add Monitoring Metrics Publisher role assignment to cluster : '" + $clusterName + "' , error : $assignmentError") -ForegroundColor Red      
       }

    } else {

       Write-Host("Successfully added Monitoring Metrics Publisher role assignment to cluster : '" + $clusterName + "'") -ForegroundColor Green 
   
    }   

    Write-Host("Completed adding role assignment for the cluster: $clusterName ...")
        
}

Write-Host("Completed adding role assignment for the aks clusters in subscriptionId :$SubscriptionId")
