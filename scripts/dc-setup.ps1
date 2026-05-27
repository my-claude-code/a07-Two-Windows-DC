Start-Transcript -Path "C:\dc-setup.log" -Append
Set-ExecutionPolicy Unrestricted -Force -Scope LocalMachine

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Write post-reboot script — decoded from the base64 embedded at Terraform plan time
[System.IO.File]::WriteAllBytes("C:\PostADSetup.ps1", [System.Convert]::FromBase64String("${post_setup_b64}"))

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
cmd /c shutdown /r /t 120 /f
exit 0
