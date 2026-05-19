Add-Computer -DomainName "contoso.local" `
 -Credential (Get-Credential) `
 -OUPath "OU=IT,OU=Contoso Corp,DC=contoso,DC=local" `
 -Restart


# Allow ajohnson to use RDP
powershellAdd-LocalGroupMember -Group "Remote Desktop Users" -Member "CONTOSO\ajohnson"
