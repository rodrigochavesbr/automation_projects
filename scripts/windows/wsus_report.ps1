#!powershell
## PowerShell Option
#################
#Requires -Version 3
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

## @file wsus_report
## @author Rodrigo Chaves <rschaves@kyndryl.com>
## @copyright (c) Kyndryl Inc. 2021. All Rights Reserved.
## @version if applicable, provide information
## @brief Wsus report
## @par URL
## https://github.kyndryl.net/la-innovation/next_scripts @n
##
## @par Purpose
##
## The purpose of this program is to run a Report of Wsus Server.
##
## @note
## This library is implemented for powershell version 3+. Prior versions of
## powershell will probably fail at interpreting that code.
## @note
## The powershell is supposed to run with strict mode, which mean that prohibits
## references to uninitialized variables, prohibits references to non-existent
## properties of an object, prohibits function calls that use the syntax for
## calling methods and also prohibits a variable without a name (${}) causing
## failure of the running script

################################################################################
# Licensed Materials - Property of Kyndryl
# (c) Kyndryl Inc. 2021. All Rights Reserved.
################################################################################
#
#             __/\\\\\_____/\\\__/\\\_______/\\\__/\\\\\\\\\\\\\\\_
#              _\/\\\\\\___\/\\\_\///\\\___/\\\/__\///////\\\/////__
#               _\/\\\/\\\__\/\\\___\///\\\\\\/__________\/\\\_______
#                _\/\\\//\\\_\/\\\_____\//\\\\____________\/\\\_______
#                 _\/\\\\//\\\\/\\\______\/\\\\____________\/\\\_______
#                  _\/\\\_\//\\\/\\\______/\\\\\\___________\/\\\_______
#                   _\/\\\__\//\\\\\\____/\\\////\\\_________\/\\\_______
#                    _\/\\\___\//\\\\\__/\\\/___\///\\\_______\/\\\_______
#                     _\///_____\/////__\///_______\///________\///________
#
################################################################################
#    Filename: wsus_report.ps1
# Description: The purpose of this program is to run a Report of Wsus Server.
#   Reference:
#       Input:
#      Output: JSON output
#      Usage: From Ansible:
#               script: scripts/windows/wsus_report.ps1
#                args:
#                   executable: 'PowerShell -NoProfile -NonInteractive'
#             From Powershell Prompt
#               ./wsus_report.ps1
#     Pre-req: Powershell 3
#      Author: Rodrigo Chaves <rschaves@kyndryl.com>
#    Releases:
##############################################################################

## WSUS connection process
[String]$Script:WSUSServer = "$env:COMPUTERNAME"
$Wsus = Get-WsusServer
$WSUSConfig = $Wsus.GetConfiguration()
$WSUSStats = $Wsus.GetStatus()
$DaysComputerStale = 30

#Check Stale Computers (30 days)
$computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$computerscope.ToLastReportedStatusTime = (Get-Date).AddDays(-$DaysComputerStale)
$StaleComputers = $wsus.GetComputerTargets($computerscope) | ForEach-Object {
    [pscustomobject]@{
        Computername_stale = $_.FullDomainName
        IPAddress_stale    = $_.IPAddress
        LastReported_stale = $_.LastReportedStatusTime | Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        LastSync_stale     = $_.LastSyncTime | Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        TargetGroups_stale = ($_.GetComputerTargetGroups() | Select-Object -Expand Name) -join ', '
    }
}
#End WSUS connection process

## @fn wsus_info()
## @brief This function collects Wsus information
function wsus_info() {
    #WSUS Version
    $WSUSVersion = [pscustomobject]@{
        Computername_WSUS     = $WSUS.ServerName
        Version               = $Wsus.Version.Major
        Port                  = $Wsus.PortNumber
        ServerProtocolVersion = $Wsus.ServerProtocolVersion.Major
    }
    #$WSUSConfig
    $WSUSVersion
}

## @fn OS_versions()
## @brief This function collects OS versions of endpoints
function OS_versions() {
    #Operating System
    $wsus.GetComputerTargets() | Group-Object OSDescription | Select-Object @{L = 'OperatingSystem'; E = { $_.Name } }, Count
}

## @fn wsus_generalstatus()
## @brief This function collects general status endpoints
function wsus_generalstatus() {
    $wsus.getstatus() | Select-Object UpdateCount, ApprovedUpdateCount, ComputerTargetCount, CriticalOrSecurityUpdatesNotApprovedForInstallCount,
    WsusInfrastructureUpdatesNotApprovedForInstallCount, ComputerTargetsNeedingUpdatesCount, ComputerTargetsWithUpdateErrorsCount
}

## @fn last_wsusevents()
## @brief This function collects last windows events of wsus
function last_wsusevents() {
    Get-WinEvent -FilterHashtable @{Logname = 'Application'; Providername = 'Windows Server Update Services' } -MaxEvents 1 |
    Select-Object @{n = 'TimeCreated'; e = { Get-Date ($_.TimeCreated) -Format "MM/dd/yyyy HH:mm:ss" } }, id, LevelDisplayName, Message
}

## @fn endpoint_stats()
## @brief This function collects statistics of updates
function endpoint_stats() {
    $WSUSUpdateStats = [pscustomobject]@{
        TotalUpdates        = [int]$WSUSStats.UpdateCount
        Needed              = [int]$WSUSStats.UpdatesNeededByComputersCount
        Approved            = [int]$WSUSStats.ApprovedUpdateCount
        Declined            = [int]$WSUSStats.DeclinedUpdateCount
        ClientInstallError  = [int]$WSUSStats.UpdatesWithClientErrorsCount
        UpdatesNeedingFiles = [int]$WSUSStats.ExpiredUpdateCount
    }
    $WSUSUpdateStats
}

## @fn computer_stats()
## @brief This function collects statistics of endpoints
function computer_stats() {
    $updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $updateScope.IncludedInstallationStates = 'InstalledPendingReboot'
    $computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $computerScope.IncludedInstallationStates = 'InstalledPendingReboot'
    $GroupRebootHash = @{}
    $ComputerPendingReboot = $wsus.GetComputerTargets($computerScope) | ForEach-Object {
        $Update = ($_.GetUpdateInstallationInfoPerUpdate($updateScope) | ForEach-Object {
                $Update = $_.GetUpdate()
                $Update.title
            }) -join ', '
        If ($Update) {
            $TempTargetGroups = ($_.GetComputerTargetGroups() | Select-Object -Expand Name)
            $TempTargetGroups | ForEach-Object {
                $GroupRebootHash[$_]++
            }
        } }
    $WSUSComputerStats = [pscustomobject]@{
        TotalComputers = [int]$WSUSStats.ComputerTargetCount
        StaleComputers = ($StaleComputers | Measure-Object).count
        NeedingUpdates = [int]$WSUSStats.ComputerTargetsNeedingUpdatesCount
        FailedInstall  = [int]$WSUSStats.ComputerTargetsWithUpdateErrorsCount
        PendingReboot  = ($ComputerPendingReboot | Measure-Object).Count
    }
    $WSUSComputerStats
}

## @fn wsus_drive()
## @brief This function collects information of wsus disk drive
function wsus_drive() {
    #Drive of WSUS folder
    $Drive = $WSUSConfig.LocalContentCachePath.Substring(0, 2)
    #Total Space
    $Data = Get-CIMInstance -ComputerName $WSUSServer -ClassName Win32_LogicalDisk -Filter "DeviceID='$Drive'"
    $TotalInfo = $Data.Size
    $TotalSize = $TotalInfo
    $TotalSizeGB = [System.Math]::Round((($TotalSize) / 1GB), 2)
    #Used Space
    $FolderInfo = $Data.FreeSpace
    $FolderSize = $FolderInfo
    $UsedSpaceGB = [System.Math]::Round((($FolderSize) / 1GB), 2)
    #Free Space
    $UsedSpace = $Data.Size - $Data.Freespace
    $FreeSpaceGB = [System.Math]::Round((($UsedSpace) / 1GB), 2)
    #percetage Free
    $PercentFree = "{0:P}" -f ($Data.Freespace / $Data.Size)

    $WSUSDrive = [pscustomobject]@{
        LocalContentPath = [string]$WSUSConfig.LocalContentCachePath
        TotalSpaceGB     = $TotalSizeGB
        UsedSpaceGB      = $UsedSpaceGB
        FreeSpaceGB      = $FreeSpaceGB
        PercentFree      = $PercentFree
    }
    $WSUSDrive
}

## @fn endpointfailed_installation()
## @brief This function collects information about failed installation
function endpointfailed_installation() {
    #Check Failed Installations
    $updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $updateScope.IncludedInstallationStates = 'Failed'
    $computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $computerScope.IncludedInstallationStates = 'Failed'
    $GroupFailHash = @{}
    $ComputerHash = @{}
    $UpdateHash = @{}
    $ComputerFailInstall = $wsus.GetComputerTargets($computerScope) | ForEach-Object {
        $Computername = $_.FullDomainName
        $Update = ($_.GetUpdateInstallationInfoPerUpdate($updateScope) | ForEach-Object {
                $Update = $_.GetUpdate()
                $Update.title
                $ComputerHash[$Computername] += , $Update.title
                $UpdateHash[$Update.title] += , $Computername
            }) -join ', '
        If ($Update) {
            $TempTargetGroups = ($_.GetComputerTargetGroups() | Select-Object -Expand Name)
            $TempTargetGroups | ForEach-Object {
                $GroupFailHash[$_]++
            }
            [pscustomobject] @{
                Computername = $_.FullDomainName
                TargetGroups = $TempTargetGroups -join ', '
                Updates      = $Update
            }
        }
    } | Sort Computername

    $ComputerFailInstall
}

## @fn lastsynchronizationinfo()
## @brief This function collects information about last synchronization of WSUS
function lastsynchronizationinfo() {
    $subs_data = (Get-WsusServer).GetSubscription().GetLastSynchronizationInfo()
    $subs_data = New-Object PSObject @{
        StartTime = $subs_data.StartTime | Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        EndTime   = $subs_data.EndTime | Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        Error     = if ($subs_data.Error -eq 0) { "Last sync was successful" } else { 'Sync errors. Check in Wsus console' }
    }
    $subs_data
}

## @fn Format-Json()
## @brief This function Formats JSON in a nicer format than the built-in ConvertTo-Json does
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
  ($json -Split '\n' |
    ForEach-Object {
        if ($_ -match '[\}\]]') {
            # This line contains  ] or }, decrement the indentation level
            $indent--
        }
        $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
        if ($_ -match '[\{\[]') {
            # This line contains [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"
}

## @fn main()
## @brief This is main function
function main() {
    $jsonDoc = [pscustomobject]@{
        wsus_info                   = wsus_info
        wsus_drive                  = wsus_drive
        wsus_generalstatus          = wsus_generalstatus
        last_wsusevents             = last_wsusevents
        computer_stats              = computer_stats
        endpoint_stats              = endpoint_stats
        OS_versions                 = OS_versions
        endpointfailed_installation = endpointfailed_installation
        lastsynchronizationinfo     = lastsynchronizationinfo
    }

    $jsonDoc | ConvertTo-Json | Format-Json
}

main
