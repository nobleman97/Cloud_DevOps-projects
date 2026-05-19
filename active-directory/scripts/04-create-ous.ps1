$domain = "DC=contoso,DC=local"

# Top-level OU
New-ADOrganizationalUnit -Name "Contoso Corp" -Path $domain

$base = "OU=Contoso Corp,$domain"

# Department OUs
foreach ($ou in @("IT","HR","Finance","Sales","Servers","Service Accounts","_Admin")) {
   New-ADOrganizationalUnit -Name $ou -Path $base
}
