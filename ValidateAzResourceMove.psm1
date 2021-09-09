<#PSScriptInfo

.VERSION 1.0.0

.GUID ec3c9d94-1245-4696-87c0-d076a9105a84

.AUTHOR Aaron Saikovski - asaikovski@outlook.com

.RELEASENOTES
    Sept 9, 2021 1.0.0        
#>
<#
.SYNOPSIS
    Validates a source Azure resource group and all child resources to check for moveability support into a target resource group within a target subscription.    
    **This will only support moving resources in a single tenant, you cannot move resources between tenants at time of writing.**
    **You will need to have logged into Azure via Login-AzAccount before running this script**

.DESCRIPTION
    This script takes a Source SubscriptionID and Source ResourceGroup as parameters, analyzes the subscription/resource group and gathers a list of resource Ids and excludes those resources
    that cannot be moved based on the resource ID list.
    The script builds up a Az bearer token and a Body of resource Ids and validates the resource move against the target resource group.
    The script checks for a 202 response code to get the specific management API reference for the validation to occur.
    The script will trap any errors and will output a report to the console to indicate if there are any errors (Response code 409) or success (Response code 204)

.PARAMETER SourceSubscriptionId
    The Source subscription you want to migrate resources from. Typically an EA subscription.

.PARAMETER SourceResourceGroup
    The source resourcegroup where original Azure resources are located.

.PARAMETER TargetSubscriptionId
    The Target subscription you want to migrate resources To. Typically a CSP subscription.

.PARAMETER TargetResourceGroup
    The Target resourcegroup where the resources you want to move resources into.

.EXAMPLE
  ValidateMoveResources -SourceSubscriptionId "XXXX-XXXX-XXXX-XXXX" -SourceResourceGroup "SourceRSG" -TargetSubscriptionId "XXXX-XXXX-XXXX-XXXX" -TargetResourceGroup "TargetRSG"

#>

#Requires -Version 7.1
#Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

#region AccessTokenFunctions
# Get the bearer token as already signed into Azure
#https://gallery.technet.microsoft.com/scriptcenter/Easily-obtain-AccessToken-3ba6e593
function Get-AzCachedAccessToken()
{
    if(-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azProfile.Accounts){
        Write-Error "Ensure you have logged in before calling this function."
    }

    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
#endregion AccessTokenFunctions

#region ValidateMoveResources
function ValidateMoveResources {
    [CmdletBinding()]
	param(
	  [Parameter(Mandatory=$True)]
	  [string] $SourceSubscriptionId,

	  [Parameter(Mandatory=$True)]
      [string] $SourceResourceGroup,
      
      [Parameter(Mandatory=$True)]
	  [string] $TargetSubscriptionId,

	  [Parameter(Mandatory=$True)]
	  [string] $TargetResourceGroup
	)
   
    #Local Vars
    $resourceids = $null
    $BearerToken = $null
    $RequestHeader
    $Body=$null
    $APIResponse=$null
    $APIStatus="202"
    $ApiTmpResp = $null     
    $ValidateAPIStatusCode = "202"
    $ValidateAPIResponse = $null
 
    # Select the source subscription, so we can dynamically get a list of resources
    Select-AzSubscription $SourceSubscriptionId | Out-Null
    
    #check we actually have resources in the resourcegroup...exit
    if((Get-AzResource -ResourceGroupName $SourceResourceGroup).Count -eq 0)
    {
        Write-Output "No resources found in Source ResourceGroup - $SourceResourceGroup"
        return 0
    }
    
    # Get all resources within the source resource group
    $resourceids = get-azresource -resourcegroupname $SourceResourceGroup
    
    # Remove resource types that we know are incompatible with the move operation.
    #Supported list of moveable resources - https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/move-support-resources
    $resourceids = $resourceids | Where-Object { $_.ResourceType -notlike "*/configurations"`
     -and $_.ResourceType -notlike "*/extensions*"`
     -and $_.ResourceType -notlike "*/applicationgateways*"`
    }

    #Convert our array to JSON to pass into the body
    $resourceids = $resourceids.resourceid | ConvertTo-JSON
    
    # Get our bearer token because we're already signed into Azure
    ##. .\Get-AzCachedAccessToken.ps1 #https://gallery.technet.microsoft.com/scriptcenter/Easily-obtain-AccessToken-3ba6e593
    $BearerToken = ('Bearer {0}' -f (Get-AzCachedAccessToken))
    $RequestHeader = @{
        "Content-Type"  = "application/json";
        "Authorization" = "$BearerToken"
    }
    
    # Build the Body variable, using our $resourceids array
$Body = @"
{
"resources": $resourceids,
"targetResourceGroup": "/subscriptions/$TargetSubscriptionId/resourceGroups/$TargetResourceGroup"
}
"@
    
    #Obtain the Move API reference - Return code 409 means an error
    try
    {
        $URI = "https://management.azure.com/subscriptions/$SourceSubscriptionId/resourceGroups/$SourceResourceGroup/validateMoveResources?api-version=2020-06-01"
        $APIResponse = Invoke-WebRequest -Uri $URI -Method POST -body $body -header $RequestHeader
    
        # This will only execute if the Invoke-WebRequest is successful.
        $APIStatus = $APIResponse.StatusCode
    }
    catch
    {
        $APIStatus = $_.Exception.Response.StatusCode.value__
        Write-Output "***ERROR - $_.Exception.Response ***"        
    }
    
    #Main API - Status code success - 202
    if($APIStatus -eq "202") 
    {
        # From the returned response, find the Location section of the string and extract it
        $ApiTmpResp = $APIResponse.rawcontent 
    
        ##Get the Validation managment URI from the raw content string payload    
        $intStart=$ApiTmpResp.IndexOf('https:')
        $tmpStr = $ApiTmpResp.Substring($intStart)        
        $newStr = $tmpStr.Substring(0,$tmpStr.LastIndexOf('06-01')+5) #TODO: could be handled better
        $checkURI = $newStr.Trim()
    
        #Perform the validation of resource move against the API
        ## Return codes:
        ##  Success == HTTP response code 204 (no content)
        ##  Error == HTTP response code 409 (Conflict)  
        try
        {
            #do the loop until we arent receiving a 202 return code back
            #API doesnt get call the first time around due to throttling/the API not being called
            while($ValidateAPIStatusCode -eq "202")
            {
                $ValidateAPIResponse = Invoke-WebRequest -Uri $checkURI -Method Get -header $RequestHeader 
    
                # This will only execute if the Invoke-WebRequest is successful.
                $ValidateAPIStatusCode = $ValidateAPIResponse.StatusCode
    
                #wait 3 seconds before retrying API Call
                Start-Sleep -Seconds 3 
            }       
        }
        catch
        {   #[AZMIG-3] 
            Write-Output "**************************************************************"    
            Write-Output "*** Source ResourceGroup - $SourceResourceGroup ***"
            Write-Output "*** Error Details -  $_  ***"
            Write-Output "**************************************************************" 
        }
    
        #check for the status code result 
        if($ValidateAPIStatusCode -eq "204") #Success!!
        {
            Write-Output "**************************************************************" 
            Write-Output "*** SUCCESS - No Azure Resource move issues found. ***" 
            Write-Output "**************************************************************"
        }
       
    }
}
#endregion ValidateMoveResources

#export Validate Function only
Export-ModuleMember -Function ValidateMoveResources