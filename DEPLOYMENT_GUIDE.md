# Cyber Exercise — Deployment Guide

## Centralized Deployment via PsExec

Everything is controlled from **one admin machine**. You run a single command and all 7 PCs get armed simultaneously over the LAN. No need to walk to each PC.

---

## Architecture

```
  [Your Admin PC] ──── switch ──── [PC-01]
        │                           [PC-02]
        │         (RJ45 LAN)        [PC-03]
        │                           [PC-04]
   deploy_all.ps1                   [PC-05]
   pushes scripts                   [PC-06]
   via PsExec + C$                  [PC-07]
```

At 14:30, each PC independently fires its scheduled task — no dependency on the admin PC.

---

## Files

```
scripts/
├── deploy_all.ps1      ← THE master script (run from admin PC)
├── lockout_pc.ps1      ← Lockout payload (auto-pushed to each PC)
├── recover_pc.ps1      ← Emergency recovery (auto-pushed when needed)
└── PsExec64.exe        ← Download from Microsoft Sysinternals, place here
```

---

## Prerequisites

1. **PsExec64.exe** — Download from https://learn.microsoft.com/en-us/sysinternals/downloads/psexec and put it in the `scripts/` folder

2. **Admin shares accessible** — From your admin PC, verify you can reach each PC:
   ```
   dir \\192.168.1.11\C$
   ```
   If this works, you're good. If not, on each PC run:
   ```powershell
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
   ```

3. **Same local admin credentials** on all 7 PCs (or domain admin)

4. **Edit the IP list** in `deploy_all.ps1` — open the file and change the `$TargetPCs` array to match your actual IPs:
   ```powershell
   $TargetPCs = @(
       "192.168.1.11"    # PC-01
       "192.168.1.12"    # PC-02
       "192.168.1.13"    # PC-03
       "192.168.1.14"    # PC-04
       "192.168.1.15"    # PC-05
       "192.168.1.16"    # PC-06
       "192.168.1.17"    # PC-07
   )
   ```

---

## Commands (All Run from Admin PC)

### 1. Deploy — Arm all PCs for 14:30

```powershell
.\deploy_all.ps1
```

With explicit credentials:
```powershell
.\deploy_all.ps1 -Username "Administrator" -Password "YourPassword"
```

Custom date/time:
```powershell
.\deploy_all.ps1 -AttackDate "2026-03-20" -AttackTime "15:00"
```

Output:
```
[192.168.1.11] ARMED
[192.168.1.12] ARMED
[192.168.1.13] ARMED
...
Results: 7 armed / 0 failed
```

### 2. Trigger Now — Fire immediately (skip the timer)

```powershell
.\deploy_all.ps1 -Action trigger
```

Useful if you want to demo or the schedule didn't work.

### 3. Cancel — Abort before it fires

```powershell
.\deploy_all.ps1 -Action cancel
```

Removes the scheduled task and exercise files from all PCs.

### 4. Recover — Emergency undo on all PCs

```powershell
.\deploy_all.ps1 -Action recover
```

Pushes the recovery script and executes it on each reachable PC. Any unreachable PC needs manual recovery (see below).

---

## Exercise Day Timeline

| Time | Action |
|------|--------|
| Morning | Run `.\deploy_all.ps1` from admin PC — confirm 7/7 armed |
| 13:45 | Final check — all PCs on, students not logged in yet |
| 14:00 | Medical students start working on the PCs |
| **14:30** | **Lockout triggers automatically on all 7 PCs** |
| 14:30+ | Medical students → pen & paper |
| 14:30+ | IT students start incident response |
| End | Run `.\deploy_all.ps1 -Action recover` for any remaining locked PCs |

---

## What Students Will See

- Fullscreen red/black screen: skull + "YOU HAVE BEEN HACKED"
- Task Manager disabled (greyed out in Ctrl+Alt+Del)
- Rebooting brings back the lockscreen (shell is replaced)
- Desktop / Explorer not accessible
- Small footer: `[ CYBER EXERCISE — HOSPICES CIVILS DE LYON ]`

---

## Expected Recovery Path (What IT Students Must Figure Out)

1. **Boot into Safe Mode** — hold Shift + click Restart, or force-shutdown 3 times to trigger Windows Recovery → Safe Mode with Command Prompt
2. **Open regedit** and fix:
   - `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon` → delete `Shell` value
   - `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System` → delete `DisableTaskMgr`
3. **Remove the scheduled task**: `schtasks /delete /tn CyberExercise_Lockout /f`
4. **Delete** `C:\CyberExercise` folder
5. **Restart** normally

---

## Manual Recovery (if a PC is unreachable from network)

Boot into Safe Mode with Command Prompt, then:

```cmd
reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoLogoff /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoChangeStartMenu /f
schtasks /delete /tn CyberExercise_Lockout /f
rmdir /s /q C:\CyberExercise
shutdown /r /t 0
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `dir \\PC\C$` access denied | Enable remote admin shares (see Prerequisites step 2) |
| PsExec hangs | Add `-Username` and `-Password` params explicitly |
| Task didn't fire at 14:30 | Check PC system clock; or use `.\deploy_all.ps1 -Action trigger` |
| Student somehow closed HTA | Reboot relocks them (shell replacement) |
| Can't reach PC after lockout | Expected — RDP/remote still works, but student's session is locked. Use PsExec recovery. |
| PsExec EULA prompt | Already handled with `-accepteula` flag |
