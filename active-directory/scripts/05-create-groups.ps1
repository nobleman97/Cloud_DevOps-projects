$groups = @("IT-Team","HR-Team","Finance-Team","Sales-Team")
foreach ($g in $groups) {
   New-ADGroup -Name $g -GroupScope Global -GroupCategory Security `
     -Path "OU=IT,OU=Contoso Corp,DC=contoso,DC=local"
}
