#!powershell

#
## PowerShell Option
#################
#Requires -Version 2
Set-StrictMode -Version 2
# Set Error Action to Stop
$ErrorActionPreference = 'Stop'

#    Filename: computersystem.ps1
# Description: Retrieve Windows operating system information and parse SSS files
#   Reference:
#       Input: SSS txt file and JSON path for output
#      Output: JSON file and log
#       Usage: ./computersystem.ps1 -sss_file <SSS file path>
#     Pre-req: Ps1 execution must be enabled on endpoint
#      Author: Rodrigo Chaves <rschavesbr@gmail.com>
################################################################################

## @var String sss_file
## @brief Retains the path of SSS results
[String]$Script:SSS_FILE = ''
[string]$Script:CSV_FILE = ''

## @var String SCRIPT_NAME
## @brief Contains the own script name
[String]$Script:SCRIPT_NAME = $MyInvocation.MyCommand.Name

## @var String WMIbios
## @brief Retains the BIOS information
[Object]$Script:WMIbios = Get-WmiObject Win32_BIOS
if ($null -eq $Script:WMIbios) {
  $Script:WMIbios = Get-CimInstance Win32_BIOS
}

## @var String WMIsystem
## @brief Reatins the computer system information
[Object]$Script:WMIsystem = Get-WmiObject Win32_ComputerSystem
if ($null -eq $Script:WMIsystem) {
  $Script:WMIsystem = Get-CimInstance Win32_ComputerSystem
}

## @var String WMIos
## @brief Retains the operating system
[Object]$Script:WMIos = Get-WmiObject Win32_OperatingSystem
if ($null -eq $Script:WMIos) {
  $Script:WMIos = Get-CimInstance Win32_OperatingSystem
}

## @var String WMItz
## @brief Retains the timezone
[Object]$Script:WMItz = Get-WmiObject Win32_TimeZone
if ($null -eq $Script:WMItz) {
  $Script:WMItz = Get-CimInstance Win32_TimeZone
}

## @var String WMIcpu
## @brief Retains information about the processor
[Object]$Script:WMIcpu = Get-WmiObject Win32_Processor
if ($null -eq $Script:WMIcpu) {
  $Script:WMIcpu = Get-CimInstance Win32_Processor
}

## @var String cpu
## @brief Retains information about the processor
[String]$Script:cpu = ''

## @var String WMIdrives
## @brief Retains information about the system drives
[Object]$Script:WMIdrives = Get-WmiObject Win32_LogicalDisk
if ($null -eq $Script:WMIdrives) {
  $Script:WMIdrives = Get-CimInstance Win32_LogicalDisk
}

## @var String WMInetwork
## @brief Retains information about the network
[Object]$Script:WMInetwork = Get-WmiObject Win32_networkadapterconfiguration
if ($null -eq $Script:WMInetwork) {
  $Script:WMInetwork = Get-CimInstance Win32_networkadapterconfiguration
}

## @var String hostname
## @brief Retains the hostname
[String]$Script:hostname = (hostname).toLower()

## @var String basedir
## @brief Retains directory of current execution
[Object]$Script:basedir = ''

## @var String computersystem_dns
## @brief Get the DNS of the host
[String]$Script:computersystem_dns = ($Script:WMInetwork | Where-Object IPEnabled -EQ $true | ForEach-Object { $_.DNSServerSearchOrder }) -join ','

## @var String ldapname
## @brief Get the LDAP name from host
[String]$Script:ldapname = '_ldap._tcp.dc._msdcs.' + $Script:WMIsystem.Domain

## @var String computersystem_ldap
## @brief Get the LDAP name from host
[String]$Script:computersystem_ldap = try {
    (Resolve-DnsName $Script:ldapname -ErrorAction SilentlyContinue | Where-Object type -EQ 'A' | ForEach-Object { $_.IPAddress }) -join ','
}
catch {
  $Script:ldapname
}

## @var String computersystem_virtual
## @brief Boolean that retains if the server is virtual or not, by default is set to false
[String]$Script:computersystem_virtual = 'false'

## @var String computersystem_manufacturer
## @brief Retains manufacturer of the endpoint
[String]$Script:computersystem_manufacturer = $Script:WMIsystem.Manufacturer

## @var String computersystem_model
## @brief Retains model of the endpoint
[String]$Script:computersystem_model = $Script:WMIsystem.Model

## @var String computersystem_serialnumber
## @brief Retains model of the endpoint
[String]$Script:computersystem_serialnumber = $Script:WMIbios.SerialNumber

## @var String sp
## @brief Retains the service pack
[String]$Script:sp = ''

## @var date
## @brief Retains the current date
[String]$Script:date = Get-Date -Format yyyy-MM-ddTHH:mm:sszzz

## @fn check_virtual()
## @brief This function will check if te server is virtual
function check_virtual() {
  if ($Script:computersystem_manufacturer.tolower() -like "vmware*" -or $Script:computersystem_manufacturer.tolower() -like "microsoft*" -or
    $Script:computersystem_manufacturer.tolower() -eq "xen" -or $Script:computersystem_model.tolower() -eq "kvm" -or
    $Script:computersystem_manufacturer.tolower() -eq "amazon ec2" -or $Script:computersystem_model.tolower() -eq "amazon ec2" -or
    $Script:computersystem_manufacturer.tolower() -eq "qemu" -or
    $Script:computersystem_model.tolower() -eq "virtualbox" -or $Script:computersystem_model.tolower() -like "virtual") {
    $Script:computersystem_virtual = 'true'
  }
  else {
    $Script:computersystem_virtual = 'false'
  }
}

## @fn setup_basedir()
## @brief This function will add the path of results for this script
function setup_basedir() {
  $Script:basedir = Join-Path $env:ProgramFiles "ansible\GTS\sss\"
}

## @fn get_service_pack()
## @brief This function will get the host service pack
function get_service_pack() {
  # Service Pack
  $Script:sp = $Script:WMIos.ServicePackMajorVersion
  if ($Script:sp -gt 0) {
    $Script:sp = "Service Pack ${Script:sp}"
  }
  else {
    $Script:sp = 'No Service Pack installed'
  }

  # $Script:WMIcpu.name may return multiple lines, let's get first only
  foreach ($cpuobject in $Script:WMIcpu) {
    $Script:cpu = $cpuobject.Name
    break
  }
}

## @fn output($text)
## @brief This will receive a text content and save on output file
## @param $text with JSON content to create the file
function output($text) {
  [IO.File]::AppendAllText("${Script:basedir}\results\${Script:hostname}.json", $text)
}

## @fn add_interfaces()
## @brief This function will populate output var as a JSON, with interfaces information collected from the server
function add_interfaces() {
  [String]$separator = ''

  output(", `"interfaces`": [")
  foreach ($Netobject in $Script:WMInetwork) {
    if ($Netobject.ipenabled -ne "true" -or $Netobject.IPAddress -eq "0.0.0.0") {
      continue
    }

    output("${separator} { ")
    output("`"classification`": `"ci.ipinterface`"")
    output(", `"relation`": `"contains`"")
    output(", `"cinum`": `"${hostname}:$($Netobject.IPAddress[0])`"")
    output(", `"ciname`": `"${hostname}:$($Netobject.IPAddress[0])`"")
    output(", `"networkinterface_ipaddress`": `"$($Netobject.IPAddress[0])`"")
    output(", `"networkinterface_netmask`": `"$($Netobject.IPSubnet[0])`"")
    output(", `"networkinterface_interfacename`": `"$($Netobject.Description)`"")
    output(", `"networkinterface_adminstate`": `"`"")
    output(", `"networkinterface_ianainterfacetype`": `"Ethernet`"")
    output(", `"networkinterface_physicaladdress`": `"$($Netobject.MACAddress)`"")
    output(' }');
    $separator = ', '
  }
  output(' ]')
}

## @fn add_disks()
## @brief This function will populate output var as a JSON, with disks information collected from the server
function add_disks() {
  [String]$separator = ''

  output(", `"filesystems`": [")
  foreach ($drive in $Script:WMIdrives) {
    if ([String]::IsNullOrEmpty($drive.size)) {
      continue
    }

    output("${separator} { ")
    output("`"classification`": `"ci.filesystem`"")
    output(", `"relation`": `"contains`"")
    output(", `"cinum`": `"${hostname}:$($drive.DeviceID)`"")
    output(", `"ciname`": `"${hostname}:$($drive.DeviceID)`"")
    output(", `"filesystem_type`": `"$($drive.Filesystem)`"")
    output(", `"filesystem_capacity`": `"$([math]::Round($drive.Size / 1048576))`"")
    output(", `"filesystem_availablespace`": `"$([math]::Round($drive.FreeSpace / 1048576))`"")
    output(", `"filesystem_mountpoint`": `"$($drive.DeviceID)`"")
    output(' }')
    $separator = ', '
  }
  output(" ]")
}

# @fn add_subsystems()
## @brief This function will populate output var as a JSON, with information collected by SSS script
function add_subsystems() {
  [String]$separator = ''
  [String]$lasttype = ''
  [String]$lastinstance = ''
  [Bool]$finishdb = $false

  # Construct the full path to the sss file and csv file
  $csvPath = $Script:CSV_FILE

  # Load the classification.csv into a hashtable
  $classificationLookup = @{}
  Import-Csv -Path $csvPath | ForEach-Object {
    $classificationLookup[$_.type] = $_.classification
  }

  output(", `"subsystems`": [")
  Import-Csv -Path $Script:SSS_FILE -Delimiter ';' `
    -Header a, b, c, d, instance, type, version, edition, fixpack, path, db, e, f, g, h, port | `
    Where-Object { $_.instance -ne 'SUBSYSTEM_INSTANCE=NO' } | `
    ForEach-Object {
    $instance = $_.instance.split('=')[1] -replace "\\", "\\"
    $instance = $instance -replace "`"", ''
    $type = $_.type.split('=')[1]
    $classification = $classificationLookup[$type]  # Lookup the classification based on the type
    $version = $_.version.split('=')[1]
    $edition = $_.edition.split('=')[1]
    $fixpack = $_.fixpack.split('=')[1]
    $path = $_.path.split('=')[1] -replace "\\", "\\"
    $path = $path -replace "`"", ''
    $db = $_.db.split('=')[1]
    $port = $_.port.split('=')[1] -replace "[^0-9]" , ''

    if (($port -Match '-1') -or ($port -notmatch '\d')) {
      $port = 0
    }

    if ($type -eq $lasttype -and $instance -eq $lastinstance -and ($type -eq 'DB2' -or $type -eq 'IFX' -or $type -eq 'MSL' -or $type -eq 'MYL' -or $type -eq 'ORA' -or $type -eq 'SYB')) {
      output(", { `"classification`": `"$classification`"")  # Use the classification
      output(", `"relation`": `"contains`"")
      output(", `"cinum`": `"${hostname}:${type}:${instance}:${db}`"")
      output(", `"ciname`": `"${hostname}:${instance}:${db}`"")
      output(", `"database_name`": `"${db}`"")
      output(' }')
    }
    else {
      output("${separator} { ")
      output("`"classification`": `"$classification`"")  # Use the classification
      if ($type -eq "ADI") {
        output(", `"relation`": `"provides`"")
      }
      else {
        output(", `"inverse_relation`": `"runson`"")
      }
      output(", `"cinum`": `"${hostname}:${type}:${instance}`"")
      output(", `"ciname`": `"${hostname}:${instance}`"")
      output(", `"appserver_productname`": `"${edition}`"")
      output(", `"appserver_productversion`": `"${version}`"")
      output(", `"appserver_servicepack`": `"${fixpack}`"")
      output(", `"appserver_vendorname`": `"`"")
      output(", `"path`": `"${path}`"")
      output(", `"port`": `"${port}`"")
      output(", `"type`": `"${type}`"")

      if ($type -eq 'DB2' -or $type -eq 'IFX' -or $type -eq 'MSL' -or $type -eq 'MYL' -or $type -eq 'ORA' -or $type -eq 'SYB') {
        output(", `"databases`": [ { ")
        output("`"classification`": `"$classification`"")  # Use the classification
        output(", `"relation`": `"contains`"")
        output(", `"cinum`": `"${hostname}:${type}:${instance}:${db}`"")
        output(", `"ciname`": `"${hostname}:${instance}:${db}`"")
        output(", `"database_name`": `"${db}`"")
        output(' }')
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
        $finishdb = $true
        $lasttype = $type
        $lastinstance = $instance
        $separator = '] }, '
      }
      else {
        output(' }')
        $finishdb = $false
        $separator = ', '
      }
    }
  }

  if ($finishdb) {
    output('] } ] ')
  }
  else {
    output(' ]')
  }
}

# @fn add_cluster()
## @brief This function will populate output var as a JSON, with cluster information collected from the server
function add_cluster() {
  # Cluster
  $WMICluster = Get-WmiObject MSCluster_Cluster -NameSpace root\mscluster -ErrorAction 'SilentlyContinue'
  foreach ($cluster in $WMICluster) {
    output("}, `"cluster`": {")
    output("`"name`": `"aaa`",")
    output("`"nodes`": [ ],")
    output("`"resources`": [ ]")
  }
}

## @fn create_json()
## @brief This function will populate output var as a JSON, with data collected from the server
function create_json() {

  output("{ `"computersystem`": { `"classification`": `"ci.windowscomputersystem`"")
  output(", `"cinum`": `"${Script:hostname}`"")
  output(", `"ciname`": `"${Script:hostname}`"")
  output(", `"hostname`": `"${Script:hostname}`"")
  output(", `"computersystem_name`": `"${Script:hostname}`"")
  output(", `"computersystem_fqdn`": `"$($Script:WMIsystem.DNSHostName).$($Script:WMIsystem.Domain)`"")
  output(", `"computersystem_virtual`": `"${Script:computersystem_virtual}`"")
  output(", `"computersystem_domain`": `"$($Script:WMIsystem.Domain)`"")
  output(", `"computersystem_dns`": `"${Script:computersystem_dns}`"")
  output(", `"computersystem_ldap`": `"${computersystem_ldap}`"")
  output(", `"computersystem_cputype`": `"${Script:cpu}`"")
  output(", `"computersystem_cpucoresenabled`": `"$($Script:WMIsystem.NumberOfLogicalProcessors)`"")
  output(", `"computersystem_numcpus`": `"$($Script:WMIsystem.NumberOfProcessors)`"")
  output(", `"computersystem_memorysize`": `"$([math]::Round($Script:WMIsystem.TotalPhysicalMemory/1048576))`"")
  output(", `"computersystem_swapmemsize`": `"`"") # rever, missing
  output(", `"computersystem_manufacturer`": `"${Script:computersystem_manufacturer}`"")
  output(", `"computersystem_serialnumber`": `"${Script:computersystem_serialnumber}`"")
  output(", `"computersystem_model`": `"${Script:computersystem_model}`"")
  output(", `"computersystem_timezone`": `"$($Script:WMItz.Caption)`"")
  output(", `"modelobject_contextip`": `"`"")

  # Operating system
  output(", `"operating_system`": { ")
  output(" `"classification`": `"ci.windowsos`"")
  output(", `"inverse_relation`": `"runson`"")
  output(", `"cinum`": `"${Script:hostname}:OS`"")
  output(", `"ciname`": `"${Script:hostname}:OS`"")
  output(", `"operatingsystem_osname`": `"$($Script:WMIos.caption)`"")
  output(", `"operatingsystem_osversion`": `"$($Script:WMIos.Version)`"")
  output(", `"operatingsystem_osmode`": `"$($Script:WMIos.OSArchitecture)`"")
  output(", `"operatingsystem_servicepack`": `"${Script:sp}`"")
  output(", `"operatingsystem_kernelversion`": `"`"")
  output(' }')

  add_interfaces
  add_disks
  add_subsystems
  add_cluster

  output(" }, `"pluspcustomer`": `"`", `"change`": `"`", `"scan_time`": `"${Script:date}`", `"jsonversion`": `"1`" }")
}

## @fn log()
## @brief This function will print the logs of execution
## @param [object] An splatted object
## @return
function log() {
  Add-Content "${Script:basedir}\results\computersystem.log" "Hostname: ${Script:hostname}"
  Add-Content "${Script:basedir}\results\computersystem.log" "Domain: ${$Script:WMIsystem.Domain}"
  #Add-Content "${Script:basedir}\results\computersystem.log" "Domain: ${$Domain}"
  Add-Content "${Script:basedir}\results\computersystem.log" "Date: ${Script:date}"
  Add-Content "${Script:basedir}\results\computersystem.log" "Virtual: ${Script:computersystem_virtual}"
  Add-Content "${Script:basedir}\results\computersystem.log" "Powershell Version: "
  Add-Content "${Script:basedir}\results\computersystem.log" $PSVersionTable.PSVersion
  Add-Content "${Script:basedir}\results\computersystem.log" Win32_BIOS
  Get-WmiObject Win32_BIOS | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
  Add-Content "${Script:basedir}\results\computersystem.log" Win32_ComputerSystem
  Get-WmiObject Win32_ComputerSystem | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
  Add-Content "${Script:basedir}\results\computersystem.log" Win32_OperatingSystem
  Get-WmiObject Win32_OperatingSystem | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
  Add-Content "${Script:basedir}\results\computersystem.log" Win32_TimeZone
  Get-WmiObject Win32_TimeZone | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
  Add-Content "${Script:basedir}\results\computersystem.log" Win32_Processor
  Get-WmiObject Win32_Processor | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
  Add-Content "${Script:basedir}\results\computersystem.log" Win32_networkadapterconfiguration
  Get-WmiObject Win32_networkadapterconfiguration | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII

  $error.clear()
  Get-WmiObject MSCluster_Cluster -NameSpace root\mscluster -ErrorAction 'SilentlyContinue'
  if ($error.Count -eq 0) {
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_Cluster"
    Get-WmiObject MSCluster_Cluster -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_Node"
    Get-WmiObject MSCluster_Node -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_ResourceGroup"
    Get-WmiObject MSCluster_ResourceGroup -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_Resource"
    Get-WmiObject MSCluster_Resource -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_Service"
    Get-WmiObject MSCluster_Service -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_Network"
    Get-WmiObject MSCluster_Network -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_NetworkInterface"
    Get-WmiObject MSCluster_NetworkInterface -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_Disk"
    Get-WmiObject MSCluster_Disk -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
    Add-Content "${Script:basedir}\results\computersystem.log" "xxxx MSCluster_DiskPartition"
    Get-WmiObject MSCluster_DiskPartition -NameSpace root\mscluster -ErrorAction 'SilentlyContinue' | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII
  }
  else {
    Add-Content "${Script:basedir}\results\computersystem.log" "Server is not a cluster"
  }

  Add-Content "${Script:basedir}\results\computersystem.log" SSS
  Get-Content "${Script:SSS_FILE}" | Select-String -Pattern "SUBSYSTEM_INSTANCE=NO" -NotMatch | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII -Width 1000

  Add-Content "${Script:basedir}\results\computersystem.log" "Windows Services"
  Get-service | Out-File "${Script:basedir}\results\computersystem.log" -Append -Encoding ASCII -Width 1000
}

## @fn handle_arguments
## @brief This function handle arguments passed to the script
## @param
## @li -sss_file <SSS file path>
## @li if no argument was passed it will exit as missing argument
function handle_arguments {
  [Int]$Counter = 0
  [String]$Value = $null

  # Ensure we have arguments, otherwise due to PowerShell strict mode it will
  # exit with error because $threshold is not set
  try {
    # check if arguments were passed in
    if ($Args.Count -eq 0) {
      throw 'No argument provided'
      # check if all arguments have its own pairs
    }
    elseif ($Args.Count % 2 -ne 0) {
      throw 'Invalid arguments size'
    }
  }
  catch {
    usage -Message "$_"
  }

  for ($Counter = 0; $Counter -lt $Args.Count; $Counter += 2) {
    # This is required in case of an exception occurs the $Args variable will be lost
    $Value = $Args[$Counter + 1]
    if ($Value.StartsWith('-')) {
      $Counter -= 1
      continue
    }

    switch ($Args[$Counter]) {
      '-sss_file' {
        $Script:SSS_FILE = $Value
      }
      '-csv_file' {
        $Script:CSV_FILE = $Value
      }
      default {
        usage -Message "Unknown option: '$($Args[$Counter])'"
      }
    }
  }

  # You should validate each argument expected individually for better error messages
  if ([String]::IsNullOrEmpty($Script:SSS_FILE)) {
    usage -Message 'Missing argument: sss_file is required.'
  }
}

## @fn usage()
## @brief Show help
## @param Custom error message
## @retval JSON and exit gracefully
function usage {
  Param (
    [Parameter(Mandatory = $True)]
    [String]$Message
  )
  [String]$UsageMessage = 'Error: \n\t{0}\nUsage: {1} -sss_file path_to_the_file ' -f "${Message}", "${Script:SCRIPT_NAME}"
  "${UsageMessage}"
  exit 1
}

## Execution
#################

## @fn main()
## @brief Main function.
## @details This function will call all others. No logic is allowed to be in there.
## @retval JSON to be used by sentinel and Next
function main {
  handle_arguments @Args
  setup_basedir
  check_virtual
  get_service_pack
  create_json
  log
}

##############################################################################
# Will call main() with arguments passed on command line.
#
main @Args

# SIG # Begin signature block
# MIIb3wYJKoZIhvcNAQcCoIIb0DCCG8wCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUZO6VDv9gphTy23Xy72zIbMmy
# 7GSgghY/MIIDMjCCAhqgAwIBAgIQa3t5dk2Oz5pPEVWyWBMWPzANBgkqhkiG9w0B
# AQsFADAxMS8wLQYDVQQDDCZLeW5kcnlsIFNNSSAtIENvZGUgU2lnbmluZyBDZXJ0
# aWZpY2F0ZTAeFw0yMzAxMDIxOTEzMjhaFw0yNDAxMDIxOTMzMjhaMDExLzAtBgNV
# BAMMJkt5bmRyeWwgU01JIC0gQ29kZSBTaWduaW5nIENlcnRpZmljYXRlMIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo30zDTAdnZpvwmPUn+VM5yI5MPk1
# mjz8GT/qm9HLE8LmY3l4ZZ4lljTxAZo68H9L6pybnzNmWhhg5d3225GRN0H0OdtR
# cPNyLetVZiFJvNMfCckclJRWg7VRd1TMScUgKU9FxIbCRWF9ziQyaZlwn1WTkg3P
# FUe2I1xtGE929Mr4S0DCZGs/3xbu0x0MJKfnFdUXwTBBLkatIs3NTug/LnTnP3iy
# nsxamgvBFo78ixCnHueVMQLweXZjjXakpJ3JsRSq4Q7c/3S9LLWJQentRvxrppI9
# qutngbCF2HMx1E3QgZSN0qU0UCR7qfYxesOz76/2JP/LYm0qwZYD4zKFvQIDAQAB
# o0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0O
# BBYEFH4uauY+u3rl7dZN33fN3Vwik8o3MA0GCSqGSIb3DQEBCwUAA4IBAQAqEGZ3
# Kv2L51yykaU+wyPu02w+KHHcsKjAQEQ6R6hOO1knqXvxpYAojDJ0BZjTqBqMCTqa
# FTJfReOnzELTWvRdQTFiiOJQUeBBSQ/Rty0cxl9U0cFq8jWe7pDTYKfAcAM4w+k5
# CR7VANP7Hhzj8r35oPIZNkYC0Pzyxykby6h0mm9gZxuZx7U0W0IRRseEvvf7m35S
# uv30OquU2WPInhTOGT+sZ0r3W7LxOFK8kj+wGMlVmTb73OF8Pr4RIyIe7nDcutwh
# SkQEkiTSvBSpmX7EVNrsAsunOsv/Lvtgrek+1Yd/JqZwsXHn9N/KmfaBFauZZSy1
# RhskEhadIM7VcXEFMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkq
# hkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBB
# c3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5
# WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQL
# ExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJv
# b3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1K
# PDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2r
# snnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C
# 8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBf
# sXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGY
# QJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8
# rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaY
# dj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+
# wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw
# ++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+N
# P8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7F
# wI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUw
# AwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAU
# Reuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEB
# BG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsG
# AQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAow
# CDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/
# Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLe
# JLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE
# 1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9Hda
# XFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbO
# byMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIG
# rjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzANBgkqhkiG9w0BAQsFADBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# HhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1ySVFVxyUDxPKRN6mXUaHW0oPR
# nkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50fng8zH1ATCyZzlm34V6gCff1D
# tITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW1OcoLevTsbV15x8G
# ZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12sy+iEZLRS8nZH92GDGd1ftFQL
# IWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYNXNXmG6jBZHRAp8ByxbpOH7G1
# WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCYJn+gGkcgQ+NDY4B7
# dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucfWmyU8lKVEStYdEAo
# q3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLcGEh/FDTP0kyr75s9
# /g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixXNXkrqPNFYLwjjVj33GHek/45
# wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtbiiKowSYI+RQQEgN9XyO7ZONj
# 4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O6V3IXjASvUaetdN2udIOa5kM
# 0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYE
# FLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/n
# upiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3Bggr
# BgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0g
# BBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQB9
# WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJLKftwig2qKWn8acHP
# HQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExiHQwIgqgWvalWzxVzjQEiJc6V
# aT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2MvGQmh2ySvZ180HAK
# fO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj+sAngkSumScbqyQeJsG33irr
# 9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJxLafzYeHJLtPo0m5
# d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZJyw9P2un8WbDQc1PtkCbISFA
# 0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SVe+0KXzM5h0F4ejjp
# nOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228Vex4Ziza4k9Tm8heZWcpw8De/
# mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJDwq9gdkT/r+k0fNX
# 2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr5n8apIUP/JiW9lVU
# Kx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBsIwggSqoAMCAQICEAVE
# r/OUnQg5pr/bP1/lYRYwDQYJKoZIhvcNAQELBQAwYzELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVk
# IEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0yMzA3MTQwMDAw
# MDBaFw0zNDEwMTMyMzU5NTlaMEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIwMjMwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCjU0WHHYOOW6w+VLMj4M+f1+XS
# 512hDgncL0ijl3o7Kpxn3GIVWMGpkxGnzaqyat0QKYoeYmNp01icNXG/OpfrlFCP
# HCDqx5o7L5Zm42nnaf5bw9YrIBzBl5S0pVCB8s/LB6YwaMqDQtr8fwkklKSCGtpq
# utg7yl3eGRiF+0XqDWFsnf5xXsQGmjzwxS55DxtmUuPI1j5f2kPThPXQx/ZILV5F
# dZZ1/t0QoRuDwbjmUpW1R9d4KTlr4HhZl+NEK0rVlc7vCBfqgmRN/yPjyobutKQh
# ZHDr1eWg2mOzLukF7qr2JPUdvJscsrdf3/Dudn0xmWVHVZ1KJC+sK5e+n+T9e3M+
# Mu5SNPvUu+vUoCw0m+PebmQZBzcBkQ8ctVHNqkxmg4hoYru8QRt4GW3k2Q/gWEH7
# 2LEs4VGvtK0VBhTqYggT02kefGRNnQ/fztFejKqrUBXJs8q818Q7aESjpTtC/XN9
# 7t0K/3k0EH6mXApYTAA+hWl1x4Nk1nXNjxJ2VqUk+tfEayG66B80mC866msBsPf7
# Kobse1I4qZgJoXGybHGvPrhvltXhEBP+YUcKjP7wtsfVx95sJPC/QoLKoHE9nJKT
# BLRpcCcNT7e1NtHJXwikcKPsCvERLmTgyyIryvEoEyFJUX4GZtM7vvrrkTjYUQfK
# lLfiUKHzOtOKg8tAewIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeAMAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkwFzAIBgZn
# gQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaaL3WMaiCP
# nshvMB0GA1UdDgQWBBSltu8T5+/N0GSh1VapZTGj3tXjSTBaBgNVHR8EUzBRME+g
# TaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRS
# U0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcBAQSBgzCB
# gDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgGCCsGAQUF
# BzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# RzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3DQEBCwUA
# A4ICAQCBGtbeoKm1mBe8cI1PijxonNgl/8ss5M3qXSKS7IwiAqm4z4Co2efjxe0m
# gopxLxjdTrbebNfhYJwr7e09SI64a7p8Xb3CYTdoSXej65CqEtcnhfOOHpLawkA4
# n13IoC4leCWdKgV6hCmYtld5j9smViuw86e9NwzYmHZPVrlSwradOKmB521BXIxp
# 0bkrxMZ7z5z6eOKTGnaiaXXTUOREEr4gDZ6pRND45Ul3CFohxbTPmJUaVLq5vMFp
# GbrPFvKDNzRusEEm3d5al08zjdSNd311RaGlWCZqA0Xe2VC1UIyvVr1MxeFGxSjT
# redDAHDezJieGYkD6tSRN+9NUvPJYCHEVkft2hFLjDLDiOZY4rbbPvlfsELWj+MX
# kdGqwFXjhr+sJyxB0JozSqg21Llyln6XeThIX8rC3D0y33XWNmdaifj2p8flTzU8
# AL2+nCpseQHc2kTmOt44OwdeOVj0fHMxVaCAEcsUDH6uvP6k63llqmjWIso765qC
# NVcoFstp8jKastLYOrixRoZruhf9xHdsFWyuq69zOuhJRrfVf8y2OMDY7Bz1tqG4
# QyzfTkx9HmhwwHcK1ALgXGC7KP845VJa1qwXIiNO9OzTF/tQa/8Hdx9xl0RBybhG
# 02wyfFgvZ0dl5Rtztpn5aywGRu9BHvDwX+Db2a2QgESvgBBBijGCBQowggUGAgEB
# MEUwMTEvMC0GA1UEAwwmS3luZHJ5bCBTTUkgLSBDb2RlIFNpZ25pbmcgQ2VydGlm
# aWNhdGUCEGt7eXZNjs+aTxFVslgTFj8wCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFLWCyUqrn1Ji
# 1KwrHvtu1Rro4AZuMA0GCSqGSIb3DQEBAQUABIIBAC0hRlCNbjhVT61Yi/LU2HYj
# UMIdeE5K6PFVH6dsp4s4JMnR64isxgkKyHEOcTIhTI1KN6HtJvK9NDBce+fkn4R2
# rjKT5UWoLjh879RhqsKEoB0LoSJSVnt6K7tgxEzleS3jup85iI/C3A+KXI2juhJY
# Eh2Le/Jo/P/eMMRsJfCOBGnzu6fNmLgGgEowlumxpyg+2Ul5Vfg0/W+6anfAc5AP
# Hn4CHJFz4CUuNhk0SK4gsDIUtKOvX2gT1jzBOMm+xBR59ybBszKmzqOEXu7P8XRZ
# CJciLSTH1ieA7ToyQ6SEavWEjSSukMga1xkCpLIq80VTG4sfcgpK/dWuEBpu+0Gh
# ggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAFRK/zlJ0IOaa/
# 2z9f5WEWMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEH
# ATAcBgkqhkiG9w0BCQUxDxcNMjMxMTA3MTY0MDA2WjAvBgkqhkiG9w0BCQQxIgQg
# drSYCpOHJOo7YXcpPlMp7J6uT9o7OPV7N0mts4jcshkwDQYJKoZIhvcNAQEBBQAE
# ggIAdnCmXdhG1tLABuPUA6Yd+Gfs0A74xs3enK1XPzoQw60L6/TWcVaPXJ251Tm3
# mMIlpMBE97aGZXz5MoV9C72eqxOB4sBoZS2WaH9Dk5LBM9m/bS18q45xGxINA+r1
# 4hWb5V7+F1GT+IDYiy65qD9t4G2G5/ntRXp2e9pJyflgfiQAhpHeGWu5BqAxnRA+
# L3ZOYW9+bgm8ET3WROadZ0wVXoNa1x13J86eqcre/taWhmbdaUsaE+a9cT9UvgL9
# bT3MhKIug+/gc27ccW/qyA7CRIb4NLzRaIng4pyVCh82rBR0oWpnCmvTvqYg4nvV
# O8BdrPiRnWVqtPGOZATUR6Z6pCQ0gAkIsxFbFdxuJyEPizkJqegeIZ8R3fSilxTR
# LKf4C/lTMHB6nFLbXru/g/E3maXXVDlH/Wk4jBZ+uk5oRa7JyG7CXA9gGtMHxQfz
# K3CICH8JBLPItsGZnvcN/ouSyZ/vYFaxQdbwL3cOV43etJp/BiLuZ+qFBSQg2OjO
# YmmRt7cmMGvNy2+JAT/ThD+zT4dj4iV2czQjfmGp7uY/cHUb++ZTwQ0HRHgLqsNw
# 8MgiIW5iHBwfpFsX2kTEe/7UoNQXG+T7N/Y/NpaHXHmfskNNL8lqZQNfMT5tpTFO
# R+1r1KMXDeiwzViFEARMJnk1SylaSt+4VYO1hBt0rBJDxRU=
# SIG # End signature block
