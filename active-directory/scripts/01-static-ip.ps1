# Set static IP
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "192.168.100.27" `
 -PrefixLength 24 -DefaultGateway "192.168.100.1"


### Rename the computer
Rename-Computer -NewName "DC01" -Restart
