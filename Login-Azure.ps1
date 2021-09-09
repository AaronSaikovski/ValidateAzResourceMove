#Install the Az Module
Install-Module -Name Az -AllowClobber

#Login to Azure
Login-AzAccount

Connect-AzAccount
    
#View Subscription Information
Get-AzSubscription  

#Vars
#$subscriptionName="SUBNAME" 
$SubscriptionID="<ID>"

#Select Subscription
#Syntax
#Select-AzSubscription -Subscription $subscriptionName 

Set-AzContext -SubscriptionId $SubscriptionID
(get-AzContext).Name
