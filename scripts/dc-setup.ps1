Start-Transcript -Path "C:\dc-setup.log" -Append

Set-ExecutionPolicy Unrestricted -Force -Scope LocalMachine

# Install AD DS feature
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Write post-reboot script that relaxes password policy and sets admin password to "1"
$$postSetupContent = @'
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
'@

[System.IO.File]::WriteAllText("C:\PostADSetup.ps1", $$postSetupContent)

# Register scheduled task to run post-setup after DC reboot
$$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Unrestricted -NonInteractive -File C:\PostADSetup.ps1"
$$trigger = New-ScheduledTaskTrigger -AtStartup
$$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "PostADSetup" -Action $$action -Trigger $$trigger -Principal $$principal -Force

# Promote to domain controller
$$safeModePwd = ConvertTo-SecureString "${admin_password}" -AsPlainText -Force
Install-ADDSForest `
    -DomainName "${domain_name}" `
    -DomainNetbiosName "${netbios_name}" `
    -SafeModeAdministratorPassword $$safeModePwd `
    -InstallDns `
    -NoRebootOnCompletion:$$true `
    -Force

Stop-Transcript

# Reboot to complete DC promotion — give CSE 120s to record success first
cmd /c shutdown /r /t 120 /f
exit 0
