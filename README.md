
---

## Known Issues

1. If there is an empty VNet (no connected devices or associated NICs) then the following error will get returned via the API call:

ERROR - {​​​​​​​"error":{​​​​​​​"code":"InvalidRequestContent","message":"The request content was invalid and could not be deserialized: 'Error converting value \"/subscriptions/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX/resourceGroups/<RESOURCE GROUP>/Microsoft.Network/virtualNetworks/<VNET-NAME>\" to type 'System.String[]'. Path 'resources', line 2, position 163.'."}​​​​​​​}​​​​​​​.Exception.Response 


2. The script will fail if there are no target resource groups provisioned in the destination subscription - The script will be updated at a future time to cater for this requirement.

3. When running the validation script, if the output throws the error - "MissingRegistrationsForTypes" you will need to register the resource types in the target subscription as per the following article - https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types
It is then strongly recommended to re-run the validation script to ensure the analysis completes. 
The script will list the missing resource types that need to be registered in the target subscription - For Example:

 Error Details -  {"error":{"code":"MissingRegistrationsForTypes","message":"The subscription 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX' is not registered for resource types 'Microsoft.Compute/availabilitySets (australiaeast),Microsoft.Compute/disks (australiaeast),Microsoft.Compute/images (australiaeast),Microsoft.Compute/restorePointCollections (australiaeast),Microsoft.Compute/virtualMachines (australiaeast),Microsoft.Network/networkInterfaces (australiaeast),Microsoft.Network/networkSecurityGroups (australiaeast),Microsoft.Network/publicIPAddresses (australiaeast),Microsoft.Network/virtualNetworks (australiaeast),Microsoft.Compute/virtualMachines/extensions (australiaeast)'."}}  

---
