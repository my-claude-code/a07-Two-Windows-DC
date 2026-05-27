Start-Transcript -Path "C:\post-setup.log" -Append
Import-Module ActiveDirectory

$$timeout = 300
$$elapsed = 0
while ($$elapsed -lt $$timeout) {
    try {
        Get-ADDomain -ErrorAction Stop | Out-Null
        break
    } catch {
        Start-Sleep -Seconds 10
        $$elapsed += 10
    }
}

Set-ADDefaultDomainPasswordPolicy `
    -Identity "${domain_name}" `
    -ComplexityEnabled $$false `
    -MinPasswordLength 0 `
    -MaxPasswordAge (New-TimeSpan -Days 0) `
    -MinPasswordAge (New-TimeSpan -Days 0) `
    -PasswordHistoryCount 0

Set-ADAccountPassword `
    -Identity "${admin_username}" `
    -NewPassword (ConvertTo-SecureString "1" -AsPlainText -Force) `
    -Reset

Unregister-ScheduledTask -TaskName "PostADSetup" -Confirm:$$false
Stop-Transcript
