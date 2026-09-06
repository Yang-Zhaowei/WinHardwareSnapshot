# WinHardwareSnapshot

[English](README.md) | 简体中文

一个隐私优先的 Windows 硬件快照工具，用于安全分享系统信息和 AI 辅助硬件分析。

- 默认 Safe-to-Share
- 支持 Windows PowerShell 5.1+
- 无必要的第三方依赖
- 同时输出人类可读 TXT 与结构化 JSON
- 可选完整本地硬件清单

## 快速开始

```powershell
.\hardware_inventory.ps1
```

报告会保存到桌面的时间戳目录 `HardwareInventory_*`。

需要完整本地硬件信息时：

```powershell
.\hardware_inventory.ps1 -FullMode
```

> `-FullMode` 可能包含机器特定标识信息。公开分享前请先检查输出内容。

### PowerShell 阻止脚本运行？

如果 PowerShell Execution Policy 阻止脚本运行，可以仅为当前 PowerShell 会话临时允许执行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

然后重新运行脚本。

关闭当前 PowerShell 会话后该设置会自动失效。只应对来源可信且已检查的代码绕过执行策略。

## 参数

| 参数 | 作用 |
| --- | --- |
| `-AssetLabel "PC-001"` | 设置设备标签 |
| `-SaveConfig` | 将 AssetLabel 保存到本地配置 |
| `-FullMode` | 收集完整本地硬件信息 |
| `-NoOpen` | 完成后不自动打开输出目录 |

示例：

```powershell
.\hardware_inventory.ps1 -AssetLabel "PC-001" -SaveConfig
```

AssetLabel 的读取优先级：

```text
-AssetLabel → hardware_inventory.config.json → UNASSIGNED
```

本地 `hardware_inventory.config.json` 默认不会进入 Git。配置示例见 [`hardware_inventory.config.example.json`](hardware_inventory.config.example.json)。

## 输出

每次运行生成 TXT 报告和结构化 JSON 快照：

```text
HardwareInventory_*/
├── hardware_inventory.txt
└── hardware_inventory.json
```

快照覆盖 CPU、内存、GPU、主板、BIOS、物理磁盘、分区、卷及盘符映射、网络硬件、PCI/USB 控制器、TPM、Secure Boot、虚拟化等主要系统与硬件信息。

管理员权限并非必须，但部分存储可靠性信息在普通权限下可能无法获取。

如果系统中存在 NVIDIA `nvidia-smi`，脚本会自动补充 GPU 运行信息。

## 隐私

默认运行模式为 Safe-to-Share。

该模式会省略计算机名、硬件序列号、MAC 地址、卷标、设备实例标识等机器特定信息，并且不会收集 USB 外设与音频设备清单。

`-FullMode` 会启用额外的本地硬件信息。

公开分享生成的报告前仍建议自行检查内容。

## 环境要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1 或更高版本

无需安装额外 PowerShell 模块。

## 项目状态

`v1.2.0` 是当前稳定基线。

已支持物理磁盘—分区—卷/盘符的层级映射。

PCIe 物理插槽和 SATA 物理端口映射仍属于 best-effort，取决于 Windows、固件和驱动实际暴露的信息。

## License

[MIT](LICENSE)