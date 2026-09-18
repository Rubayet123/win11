<h1 align="center">Win11 Service Trim</h1>

<p align="center">
  A small, honest Windows 11 service cleanup — no 100-item debloat list, no broken PC.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows-11-0078D4?logo=windows11&logoColor=white" alt="Windows 11">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
</p>

---

## What this does

Disables a short list of Windows 11 services that genuinely do nothing on a personal gaming/desktop PC — telemetry collectors, demo-mode leftovers, IoT routers — and leaves everything else alone.

**What to expect:** telemetry services like `DiagTrack` can spike RAM and CPU when they wake up, so removing them smooths out idle behaviour. The rest of the list frees very little memory. Most Windows 11 services are trigger-start and cost nothing while idle. The real win is fewer background wakeups and a smaller attack surface, not a lower number in Task Manager.

> [!WARNING]
> Every command needs an **elevated** PowerShell or Command Prompt. Run the backup step first. Windows feature updates will silently re-enable some of this.

---

## Quick start

```bat
:: Right-click -> Run as administrator
trim-services.bat
```

The script backs up your current service configuration to `%USERPROFILE%\services-baseline.csv` before changing anything, and can restore from that file at any time.

---

## Safe to disable

| Item | Recommend | Command |
|---|---|---|
| **Connected User Experiences and Telemetry** — `DiagTrack` | Disable — main telemetry collector, the usual cause of idle RAM spikes | `Stop-Service DiagTrack -Force; Set-Service DiagTrack -StartupType Disabled` |
| **WAP Push Message Routing** — `dmwappushservice` | Disable — telemetry transport, pairs with DiagTrack | `Set-Service dmwappushservice -StartupType Disabled` |
| **Diagnostics Hub Collector** — `diagnosticshub.standardcollector.service` | Disable — only used by Visual Studio profiling | `Set-Service diagnosticshub.standardcollector.service -StartupType Disabled` |
| **Downloaded Maps Manager** — `MapsBroker` | Disable — unless you use offline Maps | `Stop-Service MapsBroker -Force; Set-Service MapsBroker -StartupType Disabled` |
| **Distributed Link Tracking** — `TrkWks` | Disable — tracks moved NTFS shortcuts, rarely needed | `Stop-Service TrkWks -Force; Set-Service TrkWks -StartupType Disabled` |
| **Retail Demo Service** — `RetailDemo` | Disable — for store display units only | `Set-Service RetailDemo -StartupType Disabled` |
| **AllJoyn Router** — `AJRouter` | Disable — dead IoT protocol | `Set-Service AJRouter -StartupType Disabled` |
| **Parental Controls** — `WpcMonSvc` | Disable — on a single-adult PC | `Set-Service WpcMonSvc -StartupType Disabled` |
| **Windows Error Reporting** — `WerSvc` | Disable — if you don't send crash dumps to Microsoft | `Set-Service WerSvc -StartupType Disabled` |
| **Phone Service** — `PhoneSvc` | Disable — if not using Phone Link telephony | `Set-Service PhoneSvc -StartupType Disabled` |
| **Payments and NFC/SE** — `SEMgrSvc` | Disable — if no NFC hardware | `Set-Service SEMgrSvc -StartupType Disabled` |
| **Print Spooler** — `Spooler` | Disable **if no printer** — also closes the PrintNightmare class of bugs | `Stop-Service Spooler -Force; Set-Service Spooler -StartupType Disabled` |
| **Windows Biometric** — `WbioSrvc` | Disable **if no Hello** fingerprint/face | `Stop-Service WbioSrvc -Force; Set-Service WbioSrvc -StartupType Disabled` |
| **Windows Mobile Hotspot** — `icssvc` | Disable — if you never share the connection | `Set-Service icssvc -StartupType Disabled` |

---

## Test before disabling

| Item | Recommend | Command |
|---|---|---|
| **Windows Search** — `WSearch` | Rebuild the index first — disabling costs Start menu file search and Outlook search | `Stop-Service WSearch -Force; Set-Service WSearch -StartupType Disabled` |
| **SysMain** — `SysMain` | Test — helps on HDD, near-neutral on NVMe | `Stop-Service SysMain -Force; Set-Service SysMain -StartupType Disabled` |
| **Diagnostic Policy Service** — `DPS` | Test — can be heavy, but breaks network troubleshooters | `Stop-Service DPS -Force; Set-Service DPS -StartupType Disabled` |
| **Program Compatibility Assistant** — `PcaSvc` | Test — breaks compat shims some older games need | `Stop-Service PcaSvc -Force; Set-Service PcaSvc -StartupType Disabled` |
| **Delivery Optimization** — `DoSvc` | Prefer Settings → Windows Update → Delivery Optimization instead | `Stop-Service DoSvc -Force; Set-Service DoSvc -StartupType Disabled` |
| **Geolocation** — `lfsvc` | Disable only if you don't need auto timezone or Find My Device | `Stop-Service lfsvc -Force; Set-Service lfsvc -StartupType Disabled` |
| **Connected Devices Platform** — `CDPSvc` | Disable only if you don't use Nearby Sharing or Phone Link | `Stop-Service CDPSvc -Force; Set-Service CDPSvc -StartupType Disabled` |
| **Xbox Live Auth / Save / Net** — `XblAuthManager`, `XblGameSave`, `XboxNetApiSvc` | Disable if no Game Pass or Store games — **Steam is unaffected** | `'XblAuthManager','XblGameSave','XboxNetApiSvc' \| % { Set-Service $_ -StartupType Disabled }` |
| **Xbox Accessory Management** — `XboxGipSvc` | **Keep** if you use an Xbox controller — wired pads can stop working | `Set-Service XboxGipSvc -StartupType Disabled` |

---

## Never disable

```text
WinDefend      wuauserv    Audiosrv    AudioEndpointBuilder
Dhcp           Dnscache    NlaSvc      EventLog
RpcSs          DcomLaunch  PlugPlay    Schedule
CryptSvc       BITS        Winmgmt     NcbService
UserManager    ProfSvc     TextInputManagementService
```

Breaking these produces failures that look nothing like a service problem — the worst kind of bug to hand a user.

---

## Telemetry: the service is only half of it

`DiagTrack` restarts its work through scheduled tasks. To actually stop it:

```powershell
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f

schtasks /Change /TN "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /Disable
schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /Disable
```

---

## Backup and restore

```powershell
# Baseline — do this first
Get-Service | Select-Object Name,DisplayName,StartType,Status |
    Export-Csv "$env:USERPROFILE\services-baseline.csv" -NoTypeInformation

# Restore one service to its original state
$b = Import-Csv "$env:USERPROFILE\services-baseline.csv"
$s = $b | Where-Object Name -eq 'DiagTrack'
Set-Service $s.Name -StartupType $s.StartType
```

---

## Verify

```powershell
# Current state of a service
Get-Service DiagTrack

# Top memory consumers
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name,
    @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize

# Live CPU usage (Get-Process CPU is cumulative seconds, not current load)
Get-Counter '\Process(*)\% Processor Time' -MaxSamples 1
```

Reboot, wait five minutes, then measure. Windows runs indexing and update work right after boot, so early readings mean nothing.

---

## Notes

- `RemoteRegistry` is **already disabled** by default on Windows 11 — no action needed.
- `Set-Service` fails on a few protected services. Fall back to `sc.exe config <Name> start= disabled` (the space after `start=` is required).
- Per-user services (`CDPUserSvc_xxxxx`, `OneSyncSvc_xxxxx`) carry a random suffix and need a registry edit on the template key to stay disabled.

---

## Disclaimer

This repo changes service and scheduled-task configuration. Use it selectively. The goal is removing genuinely unused background components, not disabling as many services as possible.

**License:** MIT
