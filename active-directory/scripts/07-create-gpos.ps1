New-GPO -Name "Security Baseline"
New-GPLink -Name "Security Baseline" -Target "OU=Contoso Corp,DC=contoso,DC=local"

New-GPO -Name "Workstation Lockdown"
# Link to each non-IT OU
foreach ($ou in @("HR","Finance","Sales")) {
   New-GPLink -Name "Workstation Lockdown" `
     -Target "OU=$ou,OU=Contoso Corp,DC=contoso,DC=local"
}
