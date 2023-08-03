#!powershell
#
## PowerShell Option
#################
#Requires -Version 3
Set-StrictMode -Version 2
$ErrorActionPreference = "SilentlyContinue"

## @file healtch_check_windows
## @author Rodrigo Chaves
## @version if applicable, provide information
## @brief This is a template for using to start a new powershell script
## @details##
## @par Purpose
##
## The purpose of this program is to run a series of health checks on a server.
##
## @note
## This library is implemented for powershell version 2+. Prior versions of
## powershell will probably fail at interpreting that code.
## @note
## The powershell is supposed to run with strict mode, which mean that prohibits
## references to uninitialized variables, prohibits references to non-existent
## properties of an object, prohibits function calls that use the syntax for
## calling methods and also prohibits a variable without a name (${}) causing
## failure of the running script
##
###########################################
#    Filename: win_check_health.ps1
# Description: The purpose of this program is to run a series of health checks on a server.
#   Reference:
#       Input:
#      Output: HTML with output
#      Usage: From Ansible:
#               script: scripts/windows/win_check_health.ps1
#                args:
#                   executable: 'PowerShell -NoProfile -NonInteractive'
#             From Powershell Prompt
#               ./win_check_health.ps1
#     Pre-req: Powershell 3
#      Author: Rodrigo Chaves
#    Releases:
##############################################################################

#
## Global variables
$computer = "$env:COMPUTERNAME"

## @var String SCRIPT_NAME
## @brief Contains the own script name
[String]$Script:SCRIPT_NAME = $MyInvocation.MyCommand.Name

## @var String PS_VERSION
## @brief Contains version of the powershell
[Int]$Script:PS_VERSION = $PSVersionTable.PSVersion.Major

## @fn Generate-Report()
## @This function generate a HTML report content with colors and background
$Style = "
<style>
    BODY{background-color:#b0c4de;}
    TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
    TH{border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:#778899}
    TD{border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
    tr:nth-child(odd) { background-color:#d3d3d3;}
    tr:nth-child(even) { background-color:white;}
</style>
"
$StatusColor = @{Stopped = ' bgcolor="Red">Stopped<'; Running = ' bgcolor="Green">Running<'; }
$EventColor = @{Error = ' bgcolor="Red">Error<'; Warning = ' bgcolor="Yellow">Warning<'; }

# Path = C:\temp\"Server Name"
$ReportHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H1>System Health Check</H1>' | Out-String
$OSHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>System Information</H2>' | Out-String
$DiskHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Disk Information</H2>' | Out-String
$SysLogHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>System Log Information</H2>' | Out-String
$ServHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Services Information</H2>' | Out-String
$HotFixHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Hotfix Information</H2>' | Out-String

$TimestampAtBoot = Get-WmiObject Win32_PerfRawData_PerfOS_System |
Select-Object -ExpandProperty systemuptime
$CurrentTimestamp = Get-WmiObject Win32_PerfRawData_PerfOS_System |
Select-Object -ExpandProperty Timestamp_Object
$Frequency = Get-WmiObject Win32_PerfRawData_PerfOS_System |
Select-Object -ExpandProperty Frequency_Object
$UptimeInSec = ($CurrentTimestamp - $TimestampAtBoot) / $Frequency
$Time = (Get-Date) - (New-TimeSpan -seconds $UptimeInSec)
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('MM-dd-yyyy')

## @fn Get-RemoteProgram()
## @This function generates a list by querying the registry and returning the installed programs of a local or remote computer.
Function Get-RemoteProgram {
    begin {
        $RegistryLocation = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
        'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        $HashProperty = @{}
        $SelectProperty = @('ProgramName', 'ComputerName')
        if ($Property) {
            $SelectProperty += $Property
        }
    }

    process {
        foreach ($Computer in $ComputerName) {
            $RegBase = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $Computer)
            $RegistryLocation | ForEach-Object {
                $CurrentReg = $_
                if ($RegBase) {
                    $CurrentRegKey = $RegBase.OpenSubKey($CurrentReg)
                    if ($CurrentRegKey) {
                        $CurrentRegKey.GetSubKeyNames() | ForEach-Object {
                            if ($Property) {
                                foreach ($CurrentProperty in $Property) {
                                    $HashProperty.$CurrentProperty = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue($CurrentProperty)
                                }
                            }
                            $HashProperty.ComputerName = $Computer
                            $HashProperty.ProgramName = ($DisplayName = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue('DisplayName'))
                            if ($DisplayName) {
                                New-Object -TypeName PSCustomObject -Property $HashProperty |
                                Select-Object -Property $SelectProperty
                            }
                        }
                    }
                }
            }
        }
    }
}

## @fn Retrieve disk space status()
## @Retrieves current Disk Space Status
$Freespace =
@{
    Expression = { [int]($_.Freespace / 1GB) }
    Name       = 'Free Space (GB)'
}
$Size =
@{
    Expression = { [int]($_.Size / 1GB) }
    Name       = 'Size (GB)'
}
$PercentFree =
@{
    Expression = { [int]($_.Freespace * 100 / $_.Size) }
    Name       = 'Free (%)'
}

## @fn Get-Hotfix()
## @fn Get all instaled updates with dates and status()
function Get-Hotfix {
    $hotfix = get-windowspackage -online | ForEach-Object { get-windowspackage -online -PackageName $_.PackageName }
    $hotfix | Select-Object Description, PackageState, ReleaseType, InstallTime, RestartRequired |
    Where-Object { $_.ReleaseType -match "Update*" -or $_.ReleaseType -match "hotfix" -and $_.PackageState -match "Installed" } | Sort-Object -Property InstallTime -Descending
}

## @fn Get-Hotfix()
## @fn Get all instaled updates with dates and status()
function Get-Hotfix {
$hotfix = get-windowspackage -online | ForEach-Object{get-windowspackage -online -PackageName $_.PackageName}
$hotfix | Select-Object Description, PackageState, ReleaseType, InstallTime, RestartRequired |
Where-Object {$_.ReleaseType -match "Update*" -or $_.ReleaseType -match "hotfix" -and $_.PackageState -match "Installed" } | Sort-Object -Property InstallTime -Descending}

## @fn Gathers information status()
## @Retrieves current information for System Name, Device Disk Volume, Warning and Errors, Service information and Installed Hotfixes.

# Gathers information for System Name, Operating System, Microsoft Build Number, Major Service Pack Installed, and the last time the system was booted
$OS = Get-WmiObject -class Win32_OperatingSystem -ComputerName $computer |  Select-Object -property CSName, Caption, BuildNumber, ServicePackMajorVersion, @{n = 'LastBootTime'; e = { $_.ConvertToDateTime($_.LastBootUpTime) } } | ConvertTo-HTML -Fragment

# Gathers information for Device ID, Volume Name, Size in Gb, Free Space in Gb, and Percent of Frree Space on each storage device that the system sees
$Disk = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer | Select-Object -Property DeviceID, VolumeName, $Size, $Freespace, $PercentFree | ConvertTo-HTML -Fragment

# Gathers Warning and Errors out of the System event log.  Displays Event ID, Event Type, Source of event, Time the event was generated, and the message of the event.
$SysEvent = Get-EventLog -ComputerName $computer -LogName System -EntryType "Error" -After $Time -Newest 10 | Select-Object -property EventID, EntryType, Source, TimeGenerated, Message |  ConvertTo-HTML -Fragment

# Gathers information on Services.  Displays the service name, System name of the Service, Start Mode, and State.  Sorted by Start Mode and then State.
$Service = Get-WmiObject win32_service -ComputerName $computer | Select-Object DisplayName, Name, StartMode, State | sort StartMode, State, DisplayName | ConvertTo-HTML -Fragment

# Gathers information about Installed Hotfixes on the Machine.
$HotFix = Get-Hotfix | ConvertTo-HTML -Fragment

# Applies color coding based on cell value
$StatusColor.Keys | ForEach-Object { $Service = $Service -replace ">$_<", ($StatusColor.$_) }
$EventColor.Keys | ForEach-Object { $SysEvent = $SysEvent -replace ">$_<", ($EventColor.$_) }

# Builds the HTML report for output to C:\temp\(System Name)
ConvertTo-HTML -Head $Style -PostContent "$ReportHead $OSHead $OS $DiskHead $Disk $HotFixHead $HotFix $SysLogHead $SysEvent $ServHead $Service" -Title "System Health Check Report"  |  Out-File "C:\temp\reportwindows.html"
