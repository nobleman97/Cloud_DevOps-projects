# View all DNS zones
Get-DnsServerZone

# View A records in contoso.local
Get-DnsServerResourceRecord -ZoneName "contoso.local" -RRType A

# Add a custom record for a simulated intranet server
Add-DnsServerResourceRecordA -ZoneName "contoso.local" `
 -Name "intranet" -IPv4Address "192.168.100.29"

# Install DHCP Server role and management tools
Install-WindowsFeature DHCP -IncludeManagementTools

Add-DhcpServerv4Scope -Name "CorpLAN" `
 -StartRange "192.168.100.100" -EndRange "192.168.100.199" `
 -SubnetMask "255.255.255.0"

Set-DhcpServerv4OptionValue -ScopeId "192.168.100.0" `
 -DnsServer "192.168.100.27" -Router "192.168.100.1"

Add-DhcpServerInDC -DnsName "dc01.contoso.local"
