Install-ADDSForest `
 -DomainName "contoso.local" `
 -DomainNetBiosName "CONTOSO" `
 -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
 -InstallDns `
 -Force
 