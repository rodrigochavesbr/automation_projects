#!powershell
#
## PowerShell Option
#################
#Requires -Version 2
Set-StrictMode -Version 2
$ErrorActionPreference = 'SilentlyContinue'

## @file wsus_troubleshooting
## @author Rodrigo Chaves
## @version if applicable, provide information
## @brief roubleshooting of windows updates in a endpoint
## @par URL

##
## @par Purpose
##
## The purpose of this program is to run the troubleshooting of windows updates in a endpoint
## @note
## This library is implemented for powershell version 2+. Prior versions of
## powershell will probably fail at interpreting that code.
## @note
## The powershell is supposed to run with strict mode, which mean that prohibits
## references to uninitialized variables, prohibits references to non-existent
## properties of an object, prohibits function calls that use the syntax for
## calling methods and also prohibits a variable without a name (${}) causing
## failure of the running script

################################################################################
#    Filename: win_updates_troubleshooting.ps1
# Description: The purpose of this program is to run a Windows Update Troubleshooting
#   Reference:
#       Input:
#      Output:
#      Usage: From Ansible:
#               script: scripts/windows/win_updates_troubleshooting.ps1
#                args:
#                   executable: 'PowerShell -NoProfile -NonInteractive'
#             From Powershell Prompt
#               ./win_updates_troubleshooting.ps1
#     Pre-req: Powershell 3
#      Author: Rodrigo Chaves
#    Releases:
##############################################################################

## @var String SCRIPT_NAME
## @brief Contains the own script name
[String]$Script:SCRIPT_NAME = $MyInvocation.MyCommand.Name

## @var String PS_VERSION
## @brief Contains version of the powershell
[Int]$Script:PS_VERSION = $PSVersionTable.PSVersion.Major

$ServiceName = "BITS", "wuauserv", "appidsvc", "cryptsvc"
[System.Collections.ArrayList]$ServicesToRestart = @()


## @fn reset_WUservices()
## @brief This function reset the Windows Update Services to default settings
function reset_WUservices {
  CMD /C "sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
  CMD /C "sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
}
## @fn register_dlls()
## @brief This function register all Windows Update DLLs
function register_dlls {
  Set-Location $env:systemroot\system32
  regsvr32.exe /s atl.dll
  regsvr32.exe /s urlmon.dll
  regsvr32.exe /s mshtml.dll
  regsvr32.exe /s shdocvw.dll
  regsvr32.exe /s browseui.dll
  regsvr32.exe /s jscript.dll
  regsvr32.exe /s vbscript.dll
  regsvr32.exe /s scrrun.dll
  regsvr32.exe /s msxml.dll
  regsvr32.exe /s msxml3.dll
  regsvr32.exe /s msxml6.dll
  regsvr32.exe /s actxprxy.dll
  regsvr32.exe /s softpub.dll
  regsvr32.exe /s wintrust.dll
  regsvr32.exe /s dssenh.dll
  regsvr32.exe /s rsaenh.dll
  regsvr32.exe /s gpkcsp.dll
  regsvr32.exe /s sccbase.dll
  regsvr32.exe /s slbcsp.dll
  regsvr32.exe /s cryptdlg.dll
  regsvr32.exe /s oleaut32.dll
  regsvr32.exe /s ole32.dll
  regsvr32.exe /s shell32.dll
  regsvr32.exe /s initpki.dll
  regsvr32.exe /s wuapi.dll
  regsvr32.exe /s wuaueng.dll
  regsvr32.exe /s wuaueng1.dll
  regsvr32.exe /s wucltui.dll
  regsvr32.exe /s wups.dll
  regsvr32.exe /s wups2.dll
  regsvr32.exe /s wuweb.dll
  regsvr32.exe /s qmgr.dll
  regsvr32.exe /s qmgrprxy.dll
  regsvr32.exe /s wucltux.dll
  regsvr32.exe /s muweb.dll
  regsvr32.exe /s wuwebv.dll
}
## @fn Removing_clientSettings()
## @brief This function Removing WSUS client settings
function Removing_clientSettings {
  $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate"
  $RegProperties = "AccountDomainSid", "PingID", "SusClientId", "SusClientIdValidation"
  foreach ($RegProperty in $RegProperties) {
    try {
      Remove-ItemProperty -Path $RegPath -Name $RegProperty -ErrorAction SilentlyContinue
      Write-Output "$RegProperty deleted"
    }
    catch {
      Write-Output "$RegProperty does not exist under $RegPath"
    }
  }
  # Delete all BITS jobs
  Get-BitsTransfer | Remove-BitsTransfer
  #delete software distribution folder
  Remove-Item C:\WINDOWS\SoftwareDistribution\DataStore\DataStore.edb -Force -Recurse -ErrorAction  SilentlyContinue -Verbose
  Remove-Item C:\Windows\SoftwareDistribution\Download -Force -Recurse -ErrorAction  SilentlyContinue -Verbose
}

function Stop-DepService ($ServiceInput) {
  If ($ServiceInput.DependentServices.Count -gt 0) {
    ForEach ($DepService in $ServiceInput.DependentServices) {
      If ($DepService.Status -eq "Running") {
        Write-Output "$($DepService.Name) is running."
        $CurrentService = Get-Service -Name $DepService.Name
        # get dependancies of running service
        Stop-DepService $CurrentService
      }
      Else {
        Write-Output "$($DepService.Name) is stopped. No Need to stop or start or check dependancies."
      }
    }
  }
  Write-Output "Service to Stop $($ServiceInput.Name)"
  if ($ServicesToRestart.Contains($ServiceInput.Name) -eq $false) {
    Write-Output "Adding service to stop $($ServiceInput.Name)"
    $ServicesToRestart.Add($ServiceInput.Name)
  }
}
function start_updateservices() {
  # Reverse stop order to get start order
  $ServicesToRestart.Reverse()

  foreach ($ServiceToRestart in $ServicesToRestart) {
    Write-Output "Start Service $ServiceToRestart"
    Start-Service $ServiceToRestart -Verbose
  }
  Write-Output "-------------------------------------------"
  Write-Output "Restart of services completed"
  Write-Output "-------------------------------------------"
}

function stop_updateservices () {
  # Get the main service
  $Service = Get-Service -Name $ServiceName
  # Get dependancies and stop order
  Stop-DepService -ServiceInput $Service
  Write-Output "-------------------------------------------"
  Write-Output "Stopping Services"
  Write-Output "-------------------------------------------"
  foreach ($ServiceToStop in $ServicesToRestart) {
    Write-Output "Stop Service $ServiceToStop"
    Stop-Service $ServiceToStop -Verbose #-Force
  }
  Write-Output "-------------------------------------------"
  Write-Output "Starting Services"
  Write-Output "-------------------------------------------"
}

## @fn main()
## @brief This is the main function
function main() {
  stop_updateservices
  reset_WUservices
  register_dlls
  Removing_clientSettings
  start_updateservices
}
main
