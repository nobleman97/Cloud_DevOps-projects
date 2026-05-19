$domain = "DC=contoso,DC=local"

$users = @(
   @{First="Alice"; Last="Johnson"; Dept="IT";      OU="IT"},
   @{First="Bob";   Last="Smith";   Dept="HR";      OU="HR"},
   @{First="Carol"; Last="Davis";   Dept="Finance";  OU="Finance"},
   @{First="Dan";   Last="Lee";     Dept="Sales";    OU="Sales"}
)

foreach ($u in $users) {
   $username  = ($u.First[0] + $u.Last).ToLower()
   $upn       = "$username@contoso.local"
   $ouPath    = "OU=$($u.OU),OU=Contoso Corp,$domain"
   $password  = ConvertTo-SecureString "Welcome1!" -AsPlainText -Force

   New-ADUser `
       -GivenName       $u.First `
       -Surname         $u.Last `
       -Name            "$($u.First) $($u.Last)" `
       -SamAccountName  $username `
       -UserPrincipalName $upn `
       -Department      $u.Dept `
       -Path            $ouPath `
       -AccountPassword $password `
       -Enabled         $true `
       -PasswordNeverExpires $false `
       -ChangePasswordAtLogon $false
}
