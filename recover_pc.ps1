#==============================================================================
# RECOVER_PC.ps1 — Emergency Recovery / Instructor Answer Key
#==============================================================================

Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoLogoff" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoChangeStartMenu" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -ErrorAction SilentlyContinue

Stop-Process -Name mshta -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe

Unregister-ScheduledTask -TaskName "CyberExercise_Lockout" -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Path "C:\CyberExercise" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[*] PC recovered." -ForegroundColor Green
