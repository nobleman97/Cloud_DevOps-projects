New-Item -Path "C:\Shares\ITShare" -ItemType Directory
New-SmbShare -Name "ITShare" -Path "C:\Shares\ITShare" `
 -FullAccess "CONTOSO\IT-Team" -ReadAccess "CONTOSO\Domain Users"
