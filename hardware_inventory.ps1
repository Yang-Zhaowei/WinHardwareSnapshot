#requires -Version 5.1

param(
    [string]$AssetLabel,
    [switch]$FullMode,
    [switch]$SaveConfig,
    [switch]$NoOpen
)

# ============================================================
# Windows Hardware Inventory
# Version: 1.2
#
# Windows 10 / Windows 11
# Windows PowerShell 5.1+
# No third-party dependencies
#
# Default: Safe-to-Share
#
# AssetLabel priority:
#   1. -AssetLabel command-line parameter
#   2. hardware_inventory.config.json
#   3. UNASSIGNED
#
# Examples:
#
#   .\hardware_inventory.ps1
#
#   .\hardware_inventory.ps1 -AssetLabel "PC-001"
#
#   .\hardware_inventory.ps1 -AssetLabel "PC-001" -SaveConfig
#
#   .\hardware_inventory.ps1 -FullMode
#
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

$ScriptVersion = "1.2"
$PrivacyMode   = -not $FullMode
$ConfigPath    = Join-Path $PSScriptRoot "hardware_inventory.config.json"


# ============================================================
# CONFIGURATION
# ============================================================

if ([string]::IsNullOrWhiteSpace($AssetLabel) -and (Test-Path $ConfigPath)) {
    try {
        $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        if (-not [string]::IsNullOrWhiteSpace($Config.AssetLabel)) {
            $AssetLabel = $Config.AssetLabel
        }
    }
    catch {}
}

if ([string]::IsNullOrWhiteSpace($AssetLabel)) {
    $AssetLabel = "UNASSIGNED"
}

if ($SaveConfig) {
    if ($AssetLabel -eq "UNASSIGNED") {
        Write-Host "Config not saved: AssetLabel is UNASSIGNED." -ForegroundColor Yellow
    }
    else {
        [ordered]@{
            AssetLabel = $AssetLabel
        } |
            ConvertTo-Json |
            Set-Content $ConfigPath -Encoding UTF8

        Write-Host "AssetLabel saved to local config." -ForegroundColor Green
    }
}


# ============================================================
# BASIC SETUP
# ============================================================

$Timestamp    = Get-Date -Format "yyyyMMdd_HHmmss"
$ComputerName = $env:COMPUTERNAME
$DesktopPath  = [Environment]::GetFolderPath("Desktop")

if ($PrivacyMode) {
    $FolderName = "HardwareInventory_$Timestamp"
}
else {
    $FolderName = "HardwareInventory_$ComputerName`_$Timestamp"
}

$OutputDir = Join-Path $DesktopPath $FolderName

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$TxtFile  = Join-Path $OutputDir "hardware_inventory.txt"
$JsonFile = Join-Path $OutputDir "hardware_inventory.json"

$Inventory = [ordered]@{}


# ============================================================
# HELPERS
# ============================================================

function Add-InventorySection {
    param(
        [string]$Title,
        $Data
    )

    $script:Inventory[$Title] = $Data
}

function ConvertTo-NullableDriveLetter {
    param(
        $DriveLetter
    )

    if ($null -eq $DriveLetter) {
        return $null
    }

    if ($DriveLetter -eq [char]0) {
        return $null
    }

    $Value = [string]$DriveLetter

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return $Value
}


function Write-Section {
    param(
        [string]$Title,
        $Data
    )

    @(
        ""
        "============================================================"
        $Title
        "============================================================"
    ) | Out-File $TxtFile -Append -Encoding UTF8

    if ($null -eq $Data -or @($Data).Count -eq 0) {
        "Not available" | Out-File $TxtFile -Append -Encoding UTF8
        return
    }

    $Data |
        Format-List * |
        Out-String -Width 300 |
        Out-File $TxtFile -Append -Encoding UTF8
}

function Write-StorageMappingSection {
    param(
        $Data
    )

    @(
        ""
        "============================================================"
        "STORAGE MAPPING"
        "============================================================"
    ) | Out-File $TxtFile -Append -Encoding UTF8

    if ($null -eq $Data -or @($Data).Count -eq 0) {
        "Not available" |
            Out-File $TxtFile -Append -Encoding UTF8
        return
    }

    foreach ($Disk in $Data) {

        "Disk $($Disk.DiskNumber)" |
            Out-File $TxtFile -Append -Encoding UTF8

        "  Model          : $($Disk.FriendlyName)" |
            Out-File $TxtFile -Append -Encoding UTF8

        if ($null -ne $Disk.PSObject.Properties["SerialNumber"]) {
            "  Serial         : $($Disk.SerialNumber)" |
                Out-File $TxtFile -Append -Encoding UTF8
        }

        "  Bus            : $($Disk.BusType)" |
            Out-File $TxtFile -Append -Encoding UTF8

        "  PartitionStyle : $($Disk.PartitionStyle)" |
            Out-File $TxtFile -Append -Encoding UTF8

        "  Capacity       : $($Disk.CapacityTB) TB" |
            Out-File $TxtFile -Append -Encoding UTF8

        "  Boot/System    : $($Disk.IsBoot) / $($Disk.IsSystem)" |
            Out-File $TxtFile -Append -Encoding UTF8

        $Partitions = @($Disk.Partitions)

        if ($Partitions.Count -eq 0) {
            "  - No partitions" |
                Out-File $TxtFile -Append -Encoding UTF8
            continue
        }

        for ($i = 0; $i -lt $Partitions.Count; $i++) {

            $Partition = $Partitions[$i]

            $Prefix = "  -"

            $Details = @()

            $Details += "Partition $($Partition.PartitionNumber)"

            if (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$Partition.DriveLetter
                )
            ) {
                $Details += "$($Partition.DriveLetter):"
            }

            if (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$Partition.Role
                )
            ) {
                $Details += $Partition.Role
            }

            $Details += "$($Partition.SizeGiB) GiB"

            if (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$Partition.FileSystem
                )
            ) {
                $Details += $Partition.FileSystem
            }

            "$Prefix $($Details -join ' | ')" |
                Out-File $TxtFile -Append -Encoding UTF8
        }

        "" | Out-File $TxtFile -Append -Encoding UTF8
    }
}

function Get-PartitionRole {
    param(
        $Partition
    )

    $GptType = [string]$Partition.GptType

    if (-not [string]::IsNullOrWhiteSpace($GptType)) {
        $GptType = $GptType.Trim("{}").ToLowerInvariant()
    }

    switch ($GptType) {

        "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" {
            return "EFI System"
        }

        "e3c9e316-0b5c-4db8-817d-f92df00215ae" {
            return "Microsoft Reserved"
        }

        "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7" {
            return "Microsoft Basic Data"
        }

        "de94bba4-06d1-4d40-a16a-bfd50179d6ac" {
            return "Windows Recovery"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace(
        [string]$Partition.Type
    )) {
        return [string]$Partition.Type
    }

    return "Unknown"
}

function Get-MemoryTypeName {
    param([int]$SMBIOSMemoryType)

    switch ($SMBIOSMemoryType) {
        20 { "DDR" }
        21 { "DDR2" }
        24 { "DDR3" }
        26 { "DDR4" }
        30 { "LPDDR4" }
        34 { "DDR5" }
        35 { "LPDDR5" }

        default {
            if ($SMBIOSMemoryType) {
                "Unknown ($SMBIOSMemoryType)"
            }
            else {
                "Unknown"
            }
        }
    }
}


# ============================================================
# ADMINISTRATOR STATUS
# ============================================================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

$Principal = New-Object `
    Security.Principal.WindowsPrincipal($CurrentIdentity)

$IsAdmin = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)


# ============================================================
# SYSTEM
# ============================================================

$OSReg = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

$OperatingSystem = Get-CimInstance Win32_OperatingSystem
$ComputerSystem  = Get-CimInstance Win32_ComputerSystem

$BuildNumber = 0

if ($OSReg.CurrentBuild) {
    $BuildNumber = [int]$OSReg.CurrentBuild
}

$DetectedProductName = $OSReg.ProductName

# Legacy fields may still report "Windows 10" on Windows 11.
if (
    $BuildNumber -ge 22000 -and
    $DetectedProductName -match "Windows 10"
) {
    $DetectedProductName =
        $DetectedProductName -replace "Windows 10", "Windows 11"
}

$SystemData = [ordered]@{}

if (-not $PrivacyMode) {
    $SystemData["ComputerName"] = $ComputerName
}

$SystemData["WindowsProductName"] = $DetectedProductName
$SystemData["DisplayVersion"]     = $OSReg.DisplayVersion
$SystemData["EditionID"]          = $OSReg.EditionID
$SystemData["Build"]              = "$($OSReg.CurrentBuild).$($OSReg.UBR)"
$SystemData["Architecture"]       = $OperatingSystem.OSArchitecture

if (-not $PrivacyMode) {
    $SystemData["InstallDate"] = $OperatingSystem.InstallDate
}

$SystemData["Manufacturer"] = $ComputerSystem.Manufacturer
$SystemData["Model"]        = $ComputerSystem.Model
$SystemData["SystemType"]   = $ComputerSystem.SystemType

$System = [PSCustomObject]$SystemData

Add-InventorySection "SYSTEM" $System


# ============================================================
# CPU
# ============================================================

$CPU = Get-CimInstance Win32_Processor | ForEach-Object {
    [PSCustomObject]@{
        Name                   = $_.Name.Trim()
        Manufacturer           = $_.Manufacturer
        Socket                 = $_.SocketDesignation
        Cores                  = $_.NumberOfCores
        LogicalProcessors      = $_.NumberOfLogicalProcessors
        MaxClockMHz            = $_.MaxClockSpeed
        CurrentClockMHz        = $_.CurrentClockSpeed
        L2CacheKB              = $_.L2CacheSize
        L3CacheKB              = $_.L3CacheSize
        VirtualizationFirmware = $_.VirtualizationFirmwareEnabled
    }
}

Add-InventorySection "CPU" $CPU


# ============================================================
# MOTHERBOARD
# ============================================================

$Motherboard = Get-CimInstance Win32_BaseBoard | ForEach-Object {

    $Data = [ordered]@{
        Manufacturer = $_.Manufacturer
        Product      = $_.Product
        Version      = $_.Version
    }

    if (-not $PrivacyMode) {
        $Data["SerialNumber"] = $_.SerialNumber
    }

    [PSCustomObject]$Data
}

Add-InventorySection "MOTHERBOARD" $Motherboard


# ============================================================
# BIOS
# ============================================================

$BIOS = Get-CimInstance Win32_BIOS | ForEach-Object {
    [PSCustomObject]@{
        Manufacturer  = $_.Manufacturer
        Version       = $_.SMBIOSBIOSVersion
        ReleaseDate   = $_.ReleaseDate
        SMBIOSVersion = "$($_.SMBIOSMajorVersion).$($_.SMBIOSMinorVersion)"
    }
}

Add-InventorySection "BIOS" $BIOS


# ============================================================
# MEMORY
# ============================================================

$MemoryModules = Get-CimInstance Win32_PhysicalMemory

$MemoryTotalBytes =
    ($MemoryModules | Measure-Object Capacity -Sum).Sum

$MemorySummary = [PSCustomObject]@{
    TotalInstalledGiB = [math]::Round($MemoryTotalBytes / 1GB, 2)
    ModuleCount       = @($MemoryModules).Count
    MemoryTypes       = (
        $MemoryModules |
        ForEach-Object {
            Get-MemoryTypeName $_.SMBIOSMemoryType
        } |
        Sort-Object -Unique
    ) -join ", "
}

Add-InventorySection "MEMORY SUMMARY" $MemorySummary

$Memory = $MemoryModules | ForEach-Object {

    $Data = [ordered]@{
        Slot               = $_.DeviceLocator
        Bank               = $_.BankLabel
        Manufacturer       = $_.Manufacturer
        PartNumber         = if ($_.PartNumber) { $_.PartNumber.Trim() } else { "N/A" }
        CapacityGiB        = [math]::Round($_.Capacity / 1GB, 2)
        MemoryType         = Get-MemoryTypeName $_.SMBIOSMemoryType
        RatedSpeedMTs      = $_.Speed
        ConfiguredSpeedMTs = $_.ConfiguredClockSpeed
        ConfiguredVoltage  = $_.ConfiguredVoltage
        FormFactor         = $_.FormFactor
    }

    if (-not $PrivacyMode) {
        $Data["SerialNumber"] = $_.SerialNumber
    }

    [PSCustomObject]$Data
}

Add-InventorySection "MEMORY MODULES" $Memory


# ============================================================
# GPU
# ============================================================

$GPU = Get-CimInstance Win32_VideoController | ForEach-Object {
    [PSCustomObject]@{
        Name           = $_.Name
        DriverVersion  = $_.DriverVersion
        DriverDate     = $_.DriverDate
        VideoProcessor = $_.VideoProcessor
        Resolution     = if ($_.CurrentHorizontalResolution) {
            "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)"
        }
        else {
            "N/A"
        }
    }
}

Add-InventorySection "GPU" $GPU


# ============================================================
# NVIDIA EXTENDED
# ============================================================

if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {

    if ($PrivacyMode) {
        $NvidiaQuery =
            "name,driver_version,memory.total,memory.used,memory.free,pstate,temperature.gpu,power.draw,power.limit"
    }
    else {
        $NvidiaQuery =
            "name,driver_version,memory.total,memory.used,memory.free,pci.bus_id,pstate,temperature.gpu,power.draw,power.limit"
    }

    $NvidiaRaw = & nvidia-smi `
        --query-gpu=$NvidiaQuery `
        --format=csv,noheader,nounits `
        2>$null

    $NvidiaInfo = foreach ($Line in $NvidiaRaw) {

        $Parts = $Line -split ",\s*"

        if ($PrivacyMode) {
            [PSCustomObject]@{
                Name             = $Parts[0]
                DriverVersion    = $Parts[1]
                VRAM_Total_MB    = $Parts[2]
                VRAM_Used_MB     = $Parts[3]
                VRAM_Free_MB     = $Parts[4]
                PerformanceState = $Parts[5]
                Temperature_C    = $Parts[6]
                PowerDraw_W      = $Parts[7]
                PowerLimit_W     = $Parts[8]
            }
        }
        else {
            [PSCustomObject]@{
                Name             = $Parts[0]
                DriverVersion    = $Parts[1]
                VRAM_Total_MB    = $Parts[2]
                VRAM_Used_MB     = $Parts[3]
                VRAM_Free_MB     = $Parts[4]
                PCI_Bus_ID       = $Parts[5]
                PerformanceState = $Parts[6]
                Temperature_C    = $Parts[7]
                PowerDraw_W      = $Parts[8]
                PowerLimit_W     = $Parts[9]
            }
        }
    }

    Add-InventorySection "NVIDIA GPU EXTENDED" $NvidiaInfo
}


# ============================================================
# STORAGE DEVICES
# ============================================================

$PhysicalDiskObjects = Get-PhysicalDisk

$StorageDevices = $PhysicalDiskObjects | ForEach-Object {

    $Data = [ordered]@{
        FriendlyName      = $_.FriendlyName
        MediaType         = $_.MediaType
        BusType           = $_.BusType
        CapacityGB        = [math]::Round($_.Size / 1000000000, 2)
        CapacityTB        = [math]::Round($_.Size / 1000000000000, 2)
        HealthStatus      = $_.HealthStatus
        OperationalStatus = ($_.OperationalStatus -join ", ")
        FirmwareVersion   = $_.FirmwareVersion
        SpindleSpeedRPM   = $_.SpindleSpeed
    }

    if (-not $PrivacyMode) {
        $Data["SerialNumber"] = $_.SerialNumber
    }

    [PSCustomObject]$Data
}

Add-InventorySection "STORAGE DEVICES" $StorageDevices

# ============================================================
# STORAGE MAPPING
# ============================================================

$DiskObjects = Get-Disk | Sort-Object Number

$StorageMapping = foreach ($Disk in $DiskObjects) {

    $DiskData = [ordered]@{
        DiskNumber     = $Disk.Number
        FriendlyName   = $Disk.FriendlyName
        BusType        = [string]$Disk.BusType
        PartitionStyle = [string]$Disk.PartitionStyle
        SizeBytes      = [uint64]$Disk.Size
        CapacityGB     = [math]::Round(
            $Disk.Size / 1000000000,
            2
        )
        CapacityTB     = [math]::Round(
            $Disk.Size / 1000000000000,
            2
        )
        IsBoot          = $Disk.IsBoot
        IsSystem        = $Disk.IsSystem
    }

    if (-not $PrivacyMode) {
        $DiskData["SerialNumber"] = $Disk.SerialNumber
    }

    $PartitionData = @(
        Get-Partition -DiskNumber $Disk.Number |
            Sort-Object PartitionNumber |
            ForEach-Object {

                $Partition = $_

                $PartitionRole = Get-PartitionRole -Partition $Partition

                $Volume =
                    $Partition |
                    Get-Volume -ErrorAction SilentlyContinue |
                    Select-Object -First 1

                $DriveLetter = ConvertTo-NullableDriveLetter `
                    -DriveLetter $Partition.DriveLetter

                $Data = [ordered]@{
                    PartitionNumber      = $Partition.PartitionNumber
                    DriveLetter          = $DriveLetter
                    Type                 = $Partition.Type
                    Role                 = $PartitionRole
                    SizeBytes            = [uint64]$Partition.Size
                    SizeGiB              = [math]::Round(
                        $Partition.Size / 1GB,
                        2
                    )
                    OffsetBytes          = [uint64]$Partition.Offset
                    GptType              = $Partition.GptType
                    MbrType              = $Partition.MbrType
                    IsBoot               = $Partition.IsBoot
                    IsSystem             = $Partition.IsSystem
                    IsHidden             = $Partition.IsHidden
                    IsReadOnly           = $Partition.IsReadOnly
                    NoDefaultDriveLetter = $Partition.NoDefaultDriveLetter
                }

                if ($Volume) {

                    $Data["FileSystem"] =
                        $Volume.FileSystem

                    $Data["VolumeHealth"] =
                        $Volume.HealthStatus

                    $Data["VolumeSizeBytes"] =
                        [uint64]$Volume.Size

                    $Data["VolumeSizeGiB"] =
                        [math]::Round(
                            $Volume.Size / 1GB,
                            2
                        )

                    $Data["FreeBytes"] =
                        [uint64]$Volume.SizeRemaining

                    $Data["FreeGiB"] =
                        [math]::Round(
                            $Volume.SizeRemaining / 1GB,
                            2
                        )

                    if (-not $PrivacyMode) {
                        $Data["FileSystemLabel"] =
                            $Volume.FileSystemLabel
                    }
                }

                [PSCustomObject]$Data
            }
    )

    $DiskData["Partitions"] = $PartitionData

    [PSCustomObject]$DiskData
}

Add-InventorySection "STORAGE MAPPING" $StorageMapping

# ============================================================
# STORAGE RELIABILITY
# ============================================================

$Reliability = @()

foreach ($Disk in $PhysicalDiskObjects) {

    try {
        $Counter =
            $Disk |
            Get-StorageReliabilityCounter -ErrorAction Stop

        $Reliability += [PSCustomObject]@{
            Disk                 = $Disk.FriendlyName
            TemperatureC         = $Counter.Temperature
            PowerOnHours         = $Counter.PowerOnHours
            StartStopCycle       = $Counter.StartStopCycleCount
            LoadUnloadCycle      = $Counter.LoadUnloadCycleCount
            ReadErrorsTotal      = $Counter.ReadErrorsTotal
            WriteErrorsTotal     = $Counter.WriteErrorsTotal
            ReadErrorsCorrected  = $Counter.ReadErrorsCorrected
            WriteErrorsCorrected = $Counter.WriteErrorsCorrected
            Wear                 = $Counter.Wear
        }
    }
    catch {
        $Reliability += [PSCustomObject]@{
            Disk = $Disk.FriendlyName
            Note = "Reliability counters unavailable"
        }
    }
}

Add-InventorySection "STORAGE RELIABILITY" $Reliability


# ============================================================
# VOLUMES
# ============================================================

$Volumes = Get-Volume |
    Where-Object DriveLetter |
    ForEach-Object {

        $Data = [ordered]@{
            DriveLetter = $_.DriveLetter
            FileSystem  = $_.FileSystem
            Health      = $_.HealthStatus
            SizeGiB     = [math]::Round($_.Size / 1GB, 2)
            FreeGiB     = [math]::Round($_.SizeRemaining / 1GB, 2)

            FreePercent = if ($_.Size -gt 0) {
                [math]::Round(
                    ($_.SizeRemaining / $_.Size) * 100,
                    1
                )
            }
            else {
                0
            }
        }

        if (-not $PrivacyMode) {
            $Data["Label"] = $_.FileSystemLabel
        }

        [PSCustomObject]$Data
    }

Add-InventorySection "VOLUMES" $Volumes


# ============================================================
# NETWORK
# ============================================================

if ($PrivacyMode) {

    $Network = Get-NetAdapter |
        Where-Object {
            $_.HardwareInterface -eq $true
        } |
        ForEach-Object {
            [PSCustomObject]@{
                InterfaceDescription = $_.InterfaceDescription
                Status               = $_.Status
                LinkSpeed            = $_.LinkSpeed
                PhysicalMediaType    = $_.PhysicalMediaType
            }
        }
}
else {

    $Network = Get-NetAdapter | ForEach-Object {
        [PSCustomObject]@{
            Name                 = $_.Name
            InterfaceDescription = $_.InterfaceDescription
            Status               = $_.Status
            LinkSpeed            = $_.LinkSpeed
            MacAddress           = $_.MacAddress
            PhysicalMediaType    = $_.PhysicalMediaType
            HardwareInterface    = $_.HardwareInterface
        }
    }
}

Add-InventorySection "NETWORK ADAPTERS" $Network


# ============================================================
# USB CONTROLLERS
# ============================================================

$USBControllers =
    Get-CimInstance Win32_USBController |
    ForEach-Object {
        [PSCustomObject]@{
            Name         = $_.Name
            Manufacturer = $_.Manufacturer
            Status       = $_.Status
        }
    }

Add-InventorySection "USB CONTROLLERS" $USBControllers


# ============================================================
# USB PERIPHERALS — FULL MODE ONLY
# ============================================================

if (-not $PrivacyMode) {

    $USBDevices =
        Get-PnpDevice -Class USB |
        Where-Object {
            $_.Status -eq "OK"
        } |
        Select-Object `
            Status,
            Class,
            FriendlyName,
            InstanceId

    Add-InventorySection "USB PERIPHERALS" $USBDevices
}


# ============================================================
# PCI DEVICES
# ============================================================

$PCIRaw =
    Get-PnpDevice |
    Where-Object {
        $_.InstanceId -like "PCI\*"
    }

if ($PrivacyMode) {
    $PCI = $PCIRaw |
        Select-Object `
            Status,
            Class,
            FriendlyName
}
else {
    $PCI = $PCIRaw |
        Select-Object `
            Status,
            Class,
            FriendlyName,
            InstanceId
}

Add-InventorySection "PCI DEVICES" $PCI


# ============================================================
# AUDIO — FULL MODE ONLY
# ============================================================

if (-not $PrivacyMode) {

    $Audio =
        Get-PnpDevice -Class Media |
        Select-Object `
            Status,
            FriendlyName,
            InstanceId

    Add-InventorySection "AUDIO DEVICES" $Audio
}


# ============================================================
# MONITORS
# ============================================================

$Monitors =
    Get-CimInstance Win32_DesktopMonitor |
    ForEach-Object {
        [PSCustomObject]@{
            Name         = $_.Name
            Manufacturer = $_.MonitorManufacturer
            Width        = $_.ScreenWidth
            Height       = $_.ScreenHeight
            Status       = $_.Status
        }
    }

Add-InventorySection "MONITORS" $Monitors


# ============================================================
# BATTERY — ONLY WHEN PRESENT
# ============================================================

$BatteryRaw = Get-CimInstance Win32_Battery

if ($BatteryRaw) {

    $Battery =
        $BatteryRaw |
        ForEach-Object {
            [PSCustomObject]@{
                Name                     = $_.Name
                Status                   = $_.Status
                BatteryStatus            = $_.BatteryStatus
                EstimatedChargeRemaining = $_.EstimatedChargeRemaining
                EstimatedRunTimeMinutes  = $_.EstimatedRunTime
                DesignVoltage_mV         = $_.DesignVoltage
            }
        }

    Add-InventorySection "BATTERY" $Battery
}


# ============================================================
# TPM
# ============================================================

try {
    $TPM = Get-Tpm -ErrorAction Stop

    $TPMInfo = [PSCustomObject]@{
        Present      = $TPM.TpmPresent
        Ready        = $TPM.TpmReady
        Enabled      = $TPM.TpmEnabled
        Activated    = $TPM.TpmActivated
        Manufacturer = $TPM.ManufacturerIdTxt
    }
}
catch {
    $TPMInfo = [PSCustomObject]@{
        Status = "TPM information unavailable"
    }
}

Add-InventorySection "TPM" $TPMInfo


# ============================================================
# SECURE BOOT
# ============================================================

try {
    $SecureBootInfo = [PSCustomObject]@{
        Enabled = Confirm-SecureBootUEFI -ErrorAction Stop
    }
}
catch {
    $SecureBootInfo = [PSCustomObject]@{
        Enabled = "Unsupported or unavailable"
    }
}

Add-InventorySection "SECURE BOOT" $SecureBootInfo


# ============================================================
# POWER PLAN
# ============================================================

$PowerPlanRaw  = powercfg /GETACTIVESCHEME
$PowerPlanText = $PowerPlanRaw | Out-String

if ($PrivacyMode) {

    $PowerProfile = "Custom / Unknown"

    if (
        $PowerPlanText -match
        '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})'
    ) {

        $PowerGuid = $Matches[1].ToLower()

        switch ($PowerGuid) {
            "381b4222-f694-41f0-9685-ff5bb260df2e" {
                $PowerProfile = "Balanced"
            }

            "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" {
                $PowerProfile = "High performance"
            }

            "a1841308-3541-4fab-bc81-f71556f20b4a" {
                $PowerProfile = "Power saver"
            }

            "e9a42b02-d5df-448d-aa00-03f14749eb61" {
                $PowerProfile = "Ultimate performance"
            }
        }
    }

    $PowerPlan = [PSCustomObject]@{
        Profile = $PowerProfile
    }
}
else {
    $PowerPlan = [PSCustomObject]@{
        Raw = ($PowerPlanRaw -join " ")
    }
}

Add-InventorySection "POWER PLAN" $PowerPlan


# ============================================================
# VIRTUALIZATION
# ============================================================

$Virtualization = [PSCustomObject]@{
    FirmwareVirtualization =
        ($CPU | Select-Object -First 1).VirtualizationFirmware

    HypervisorPresent =
        $ComputerSystem.HypervisorPresent
}

Add-InventorySection "VIRTUALIZATION" $Virtualization


# ============================================================
# SUMMARY
# ============================================================

$TotalRAMGiB =
    [math]::Round(
        $MemoryTotalBytes / 1GB,
        1
    )

$TotalDiskBytes =
    ($PhysicalDiskObjects | Measure-Object Size -Sum).Sum

$TotalStorageTB =
    if ($TotalDiskBytes) {
        [math]::Round(
            $TotalDiskBytes / 1000000000000,
            2
        )
    }
    else {
        0
    }

$Summary = [PSCustomObject]@{
    AssetLabel     = $AssetLabel
    CPU            = ($CPU.Name -join "; ")
    RAM_GiB        = $TotalRAMGiB
    MemoryType     = $MemorySummary.MemoryTypes
    GPU            = ($GPU.Name -join "; ")
    Storage_TB     = $TotalStorageTB
    Motherboard    = ($Motherboard.Product -join "; ")
    Windows        = "$($System.WindowsProductName) $($System.DisplayVersion)"
    Build          = $System.Build
}


# ============================================================
# BUILD FINAL REPORT
# ============================================================

$Report = [ordered]@{}

# SUMMARY always first.
$Report["SUMMARY"] = $Summary

foreach ($Key in $Inventory.Keys) {
    $Report[$Key] = $Inventory[$Key]
}

$CompleteInfo = [PSCustomObject]@{
    Status        = "Completed successfully"
    ScriptVersion = $ScriptVersion
    PrivacyMode   = $PrivacyMode
    Administrator = $IsAdmin
}

$Report["COMPLETE"] = $CompleteInfo


# ============================================================
# EXPORT TXT
# ============================================================

foreach ($Key in $Report.Keys) {

    if ($Key -eq "COMPLETE") {
        continue
    }

    if ($Key -eq "STORAGE MAPPING") {
        Write-StorageMappingSection $Report[$Key]
        continue
    }

    Write-Section $Key $Report[$Key]
}

@(
    ""
    "============================================================"
    "COMPLETE"
    "============================================================"
    ""
    "Completed successfully | Script $ScriptVersion | Privacy: $PrivacyMode | Admin: $IsAdmin"
) |
    Out-File `
        $TxtFile `
        -Append `
        -Encoding UTF8


# ============================================================
# EXPORT JSON
# ============================================================

$Report |
    ConvertTo-Json -Depth 10 |
    Out-File `
        $JsonFile `
        -Encoding UTF8


# ============================================================
# CONSOLE
# ============================================================

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Windows Hardware Inventory v$ScriptVersion" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

if ($PrivacyMode) {
    Write-Host "Mode        : Safe-to-Share" -ForegroundColor Green
}
else {
    Write-Host "Mode        : Full Local Inventory" -ForegroundColor Yellow
}

Write-Host "Asset       : $AssetLabel"
Write-Host "Admin       : $IsAdmin"
Write-Host "Output      : $OutputDir"
Write-Host ""

if (-not $IsAdmin) {
    Write-Host "Some storage health information may require Administrator privileges." -ForegroundColor Yellow
    Write-Host ""
}

if (-not $NoOpen) {
    Invoke-Item $OutputDir
}