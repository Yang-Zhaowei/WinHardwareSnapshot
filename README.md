# WinHardwareSnapshot

English | [简体中文](README.zh-CN.md)

A privacy-first Windows hardware snapshot tool for safe sharing and AI-assisted analysis.

- Safe-to-Share by default
- Windows PowerShell 5.1+
- No required third-party dependencies
- Human-readable TXT + structured JSON output
- Optional full local inventory

## Quick start

```powershell
.\hardware_inventory.ps1
```

The report is written to a timestamped `HardwareInventory_*` folder on your Desktop.

For a full local inventory:

```powershell
.\hardware_inventory.ps1 -FullMode
```

> `-FullMode` may include machine-specific identifiers. Do not share its output publicly without reviewing it first.

### Script execution blocked?

If PowerShell prevents the script from running, you can temporarily allow script execution for the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Then run the script again.

This setting is discarded when the PowerShell session closes. Only bypass execution policy for code you trust and have reviewed.

## Options

| Option | Description |
| --- | --- |
| `-AssetLabel "PC-001"` | Set a custom machine label |
| `-SaveConfig` | Save the AssetLabel to the local config |
| `-FullMode` | Collect the full local inventory |
| `-NoOpen` | Do not open the output folder automatically |

Example:

```powershell
.\hardware_inventory.ps1 -AssetLabel "PC-001" -SaveConfig
```

AssetLabel resolution order:

```text
-AssetLabel → hardware_inventory.config.json → UNASSIGNED
```

The local `hardware_inventory.config.json` is intentionally excluded from Git. See [`hardware_inventory.config.example.json`](hardware_inventory.config.example.json).

## Output

Each run produces a TXT report and a structured JSON snapshot:

```text
HardwareInventory_*/
├── hardware_inventory.txt
└── hardware_inventory.json
```

The snapshot covers major system and hardware information including CPU, memory, GPU, motherboard, BIOS, storage, network hardware, PCI/USB controllers, TPM, Secure Boot and virtualization.

Administrator privileges are optional, but some storage reliability information may otherwise be unavailable.

If NVIDIA `nvidia-smi` is available, additional GPU telemetry is collected automatically.

## Privacy

Safe-to-Share mode is the default.

It omits machine-specific information such as the computer name, hardware serial numbers, MAC addresses, volume labels and device instance identifiers, and does not collect USB peripheral or audio-device inventories.

`-FullMode` enables additional local-only information.

Always review generated reports before sharing them publicly.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later

No additional PowerShell modules are required.

## Status

`v1.2.0` is the current stable baseline.

Hardware topology mapping is being improved incrementally. Physical PCIe slot and SATA port information depends on what Windows, firmware and device drivers expose.

## License

[MIT](LICENSE)