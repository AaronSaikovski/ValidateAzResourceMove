#Login to Azure
#Login-AzAccount

#import Powershell module
Import-Module -name .\ValidateAzResourceMove -Force -Verbose

##Variables to set
$SourceSubscriptionId=$null ###SET THIS
#$SourceResourceGroup=$null #dynamically set
$TargetSubscriptionId=$null ###SET THIS
#$TargetResourceGroup=$null #dynamic set
$SourceTenantId=$null ###SET THIS


#Set the Az Subscription Context
#Set-AzContext -SubscriptionId $SourceSubscriptionId

#Get the Subscription and Tenant Info and set the Az Context
Get-AzSubscription -SubscriptionId $SourceSubscriptionId -TenantId $SourceTenantId | Set-AzContext


#Get Resource groups..Sort alphabetically
#$rsgs = get-azresourcegroup -name <<SET_ME>> # get an individual RSG
$rsgs = get-azresourcegroup | Sort-Object -Property 'ResourceGroupName' #get all resource groups

#set output folder---change this to suit
[string]$outputfolder="C:\temp\output\"

#check that the path exists
if((Test-Path -Path $outputfolder) -eq $false)
{
    Write-error "$outputfolder does not exist"    
}

#start date time
$startdatetime = get-date
Write-Output "***Validation Started*** - $startdatetime"

#loop over the resource groups
foreach($rsg in $rsgs)
{	
    write-Host "Processing ResourceGroup - " $rsg.Resourcegroupname
    $outputfile =  ($outputfolder + $rsg.Resourcegroupname + ".txt")
    $res = get-azresource -Resourcegroupname $rsg.Resourcegroupname     
    
    #Process and write output
    Write-Output "**************************************************************" | Out-File -FilePath $outputfile
    write-output ("*** Resource Group: " + $rsg.Resourcegroupname + " has " + $res.count + " resources ***") | Out-File -FilePath $outputfile -Append

    #Call the Validation function
    ValidateMoveResources -SourceSubscriptionId $SourceSubscriptionId -SourceResourceGroup $rsg.Resourcegroupname -TargetSubscriptionId $TargetSubscriptionId -TargetResourceGroup $rsg.Resourcegroupname | Out-File -FilePath $outputfile -Append
}

#End date time
$enddatetime = get-date
Write-Output "***Validation Finished*** - $enddatetime"

#Write output on how long processing took
$timespan = new-timespan –Start $startdatetime –End $enddatetime
Write-Output ("***Total Processing Time - " + $timespan.Hours + " Hours, " + $timespan.Minutes + " Minutes, " + $timespan.Seconds + " Seconds.***")