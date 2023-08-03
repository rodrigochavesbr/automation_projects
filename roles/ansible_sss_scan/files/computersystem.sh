#!/usr/bin/env sh

#################################################################################
#    Filename: <filename of script itself>
# Description: Retrieve Unix operating system information and parse SSS files.
#   Reference: N/A
#       Input: SSS txt file
#      Output: stdout: server configuration in json format
#              stderr: debug information if DEBUG=1
#       Usage: ./computersystem.sh [SSS txt file] [JSON output file]
#     Pre-req: <pre requisites to successfully run>
#      Author: Rodrigo Chaves
#    Releases: 1.0 2020/06/15 Initial Release
#              1.1 2021/05/18 Add script to Git
################################################################################

## Global variables
#################

## @vars String
## @details Will retain values found on host and SSS results
csclassification="N/A"
osclassification="N/A"
computersystem_fqdn="N/A"
computersystem_numcpus="N/A"
computersystem_cpucoresenabled="N/A"
computersystem_cputype="N/A"
computersystem_numvirtualcpus="N/A"
computersystem_cpumode="N/A"
computersystem_memorysize="N/A"
computersystem_swapmemsize="N/A"
computersystem_manufacturer="N/A"
computersystem_model="N/A"
computersystem_serialnumber="N/A"
computersystem_virtual="N/A"
computersystem_timezone="N/A"
computersystem_dns="N/A"
modelobject_contextip="N/A"
operatingsystem_osname="N/A"
operatingsystem_osversion="N/A"
operatingsystem_servicepack="N/A"
operatingsystem_osmode="N/A"
operatingsystem_kernelversion="N/A"
sss_file="${1}"
output_file="${2}"
log_file="$(dirname "$output_file")/computersystem.log"

## @fn check_params()
## @brief Will check params received and return error to the user in case needed
## @retval Error message
check_params() {
  touch "$log_file"
  printf "Checking params \n" >> "$log_file"
  if test -z "${sss_file}" || test -z "${output_file}"; then
    printf "Usage: sss_file=path_to_sss_result sss_output=path_to_print_results %s" "$0"
    exit 1
  fi
}

## @fn export_path()
## @brief Will export default path for computer system checks
export_path() {
  printf "Exporting PATH \n"  >> "$log_file"
  export PATH="${PATH}:/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin"
}

## @fn export_path()
## @brief Retrieve information independent of operating system flavor
get_computer_system_info() {
  uname=$(uname)
  computersystem_timezone=$(date +%Z)
  computersystem_dns=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{printf "%s%s", s, $2; s=","}')
  [ -f "results/ipcmdb.csv" ] && modelobject_contextip=$(cut -f2 -d, results/ipcmdb.csv | tail -1)

  {
    printf "\n\nGetting system info \n"
    printf "Operating System Timezone: %s\n" "$(date +%Z  2>&1)"
  } >> "$log_file"

}

## @fn export_path()
## @brief Retrieve information independent of Linux architecture
get_architecture_independent_info(){
  computersystem_memorysize=$(grep MemTotal: /proc/meminfo | awk '{printf "%d", $2 / 1024}')
  computersystem_swapmemsize=$(grep SwapTotal: /proc/meminfo | awk '{printf "%d", $2 / 1024}')

  if grep "^flags.*hypervisor" /proc/cpuinfo >/dev/null 2>/dev/null; then
    if grep -i "Oracle VM Server" /etc/oracle-release >/dev/null 2>/dev/null; then
      computersystem_virtual="false"
    else
      computersystem_virtual="true"
    fi
  else
    computersystem_virtual="false"
  fi

  operatingsystem_osmode=$(uname -m)
  operatingsystem_kernelversion=$(uname -r)

  {
    printf "\n\nGet architecture independent information \n"
    printf "Command: cat /proc/meminfo \n%s\n\n" "$(cat /proc/meminfo  2>&1)"
    printf "Command: cat /proc/cpuinfo: \n%s\n" "$(cat /proc/cpuinfo  2>&1)"
    printf "Operating System OS Mode: \$(uname -m): \n%s\n" "$(uname -m  2>&1)"
    printf "Operating System Kernel Version: \n%s\n" "$(uname -r  2>&1)"
  } >> "$log_file"
}

## @fn export_path()
## @brief Retrieve information according to Linux distribution
get_linux_dependent_info() {
  scantime=$(date +%Y-%m-%dT%H:%M:%S%:z)
  hostname=$(uname -n | cut -f1 -d'.')
  ciname="${hostname}"
  [ -z "$DEBUG" ] || echo "hostname" 1>&2 && hostname 1>&2
  computersystem_fqdn=$(hostname -f)
  [ -z "$DEBUG" ] || echo "computersystem_fqdn=\$(hostname -f)" 1>&2 && hostname -f 1>&2
  csclassification="ci.linuxcomputersystem"
  osclassification="ci.linuxos"

  get_architecture_independent_info

  if [ -f /etc/oracle-release ]; then
    operatingsystem_osname=$(head -1 /etc/oracle-release | sed 's/ release.*//g')
    operatingsystem_osversion=$(head -1 /etc/oracle-release | sed -rn 's/.*release ([0-9\.]*).*/\1/p' | cut -f1-2 -d.)
    operatingsystem_servicepack="SP$(echo "${operatingsystem_osversion}" | cut -d. -f2)"
  elif [ -f /etc/redhat-release ]; then
    operatingsystem_osname=$(head -1 /etc/redhat-release | sed 's/ release.*//g')
    operatingsystem_osversion=$(head -1 /etc/redhat-release | sed -rn 's/.*release ([0-9\.]*).*/\1/p' | cut -f1-2 -d.)
    operatingsystem_servicepack="SP$(echo "${operatingsystem_osversion}" | cut -d. -f2)"
  elif [ -f /etc/fedora-release ]; then
    operatingsystem_osname=$(head -1 /etc/fedora-release | sed 's/ release.*//g')
    operatingsystem_osversion=$(head -1 /etc/fedora-release | sed -rn 's/.*release ([0-9\.]*).*/\1/p' | cut -f1-2 -d.)
    operatingsystem_servicepack="SP$(echo "${operatingsystem_osversion}" | cut -d. -f2)"
  elif [ -f /etc/SuSE-release ]; then
    operatingsystem_osname=$(head -1 /etc/SuSE-release | cut -f1-4 -d' ')
    operatingsystem_osversion=$(head -1 /etc/SuSE-release)
    grep "^VERSION" /etc/SuSE-release >/dev/null && operatingsystem_osversion=$(grep "^VERSION" /etc/SuSE-release | awk '{print $3}')
    grep "^PATCHLEVEL" /etc/SuSE-release >/dev/null && operatingsystem_servicepack="SP$(grep "^PATCHLEVEL" /etc/SuSE-release | awk '{print $3}')"
  elif [ -f /etc/lsb-release ]; then
    operatingsystem_osname=$(grep ^DISTRIB_ID= /etc/lsb-release | cut -d= -f2 | sed s/\"//g)
    operatingsystem_osversion=$(grep ^DISTRIB_RELEASE= /etc/lsb-release | cut -d= -f2 | cut -d"." -f1| sed s/\"//g)
    operatingsystem_servicepack=$(grep ^DISTRIB_RELEASE= /etc/lsb-release | cut -d= -f2 | cut -d"." -f2| sed s/\"//g)
  elif [ -f /etc/debian_version ]; then
    operatingsystem_osname="Debian"
    operatingsystem_osversion=$(cut -d"." -f1 /etc/debian_version)
    operatingsystem_servicepack=$(cut -d"." -f3 /etc/debian_version)
  elif [ -f /etc/system-release ]; then
    operatingsystem_osname=$(head -1 /etc/system-release)
    operatingsystem_osversion=$(head -1 /etc/system-release)
  elif [ -f /etc/pgp-release ]; then
    operatingsystem_osname="Symantec Encryption Server"
    operatingsystem_osversion=$(cut -d" " -f1 /etc/oem-release)
  elif [ -f /etc/os-release ]; then
    operatingsystem_osname=$(awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release | sed s/\"//g)
    operatingsystem_osversion=$(awk -F= '$1=="VERSION" { print $2 ;}' /etc/os-release | sed s/\"//g)
  else
    operatingsystem_osname="Linux"
  fi
  {
    printf "\n\nGet Linux info \n"
    printf "Scan Time: \n%s\n" "$(date +%Y-%m-%dT%H:%M:%S%:z)"
    printf "Hostname: %s\n" "$(uname -n | cut -f1 -d'.')"
    printf "Command: ls /etc/*release \n%s\n\n" "$(ls /etc/*release  2>&1)"
    printf "Command: cat /etc/*release \n%s\n\n" "$(cat /etc/*release  2>&1)"
  } >> "$log_file"


  # zLinux:
  if [ -f /proc/sysinfo ]; then
    computersystem_cputype=$(grep -E "^vendor_id" /proc/cpuinfo | head -n1 | awk '{print $NF}')
    computersystem_numcpus=$(grep -E "^#" /proc/cpuinfo | head -n1 | awk '{print $NF}')
    computersystem_cpucoresenabled=${computersystem_numcpus}
    computersystem_manufacturer="IBM"
    computersystem_model=$(grep ^Type: /proc/sysinfo | awk '{print $NF}')
    computersystem_serialnumber="N/A"
    printf "cat /proc/sysinfo: \n%s\n" "$(cat /proc/sysinfo  2>&1)" >> "$log_file"

  # non-zLinux:
  else
    computersystem_cputype=$(grep -m 1 "model name" /proc/cpuinfo | cut -d":" -f 2 | sed 's/^\ //' | tr -s ' ' ' ')
    computersystem_cpucoresenabled=$(grep -c "^processor" /proc/cpuinfo)
    computersystem_numcpus=$(grep "^physical id" /proc/cpuinfo | sort -u | wc -l)

    if dmidecode > /dev/null 2>/dev/null; then
      computersystem_manufacturer=$(dmidecode -s system-manufacturer | grep -v "^#" | head -1)
      printf "computersystem_manufacturer=\$(dmidecode -s system-manufacturer): \n%s\n" "$(dmidecode -s system-manufacturer  2>&1)" >> "$log_file"
      computersystem_model=$(dmidecode -s system-product-name | grep -v "^#" | head -1)
      printf "computersystem_model=\$(dmidecode -s system-product-name): \n%s\n" "$(dmidecode -s system-product-name  2>&1)" >> "$log_file"
      computersystem_serialnumber=$(dmidecode -s system-serial-number | grep -v "^#" | head -1)
      printf "computersystem_serialnumber=\$(dmidecode -s system-serial-number): \n%s\n" "$(dmidecode -s system-serial-number  2>&1)" >> "$log_file"
    fi
  fi
}

## @fn get_aix_dependent_info()
## @brief Get OS information of AIX architecture
get_aix_dependent_info() {
  scantime=$(perl -MTime::Local -e '@t=localtime(time);$o=(timegm(@t)-timelocal(@t))/60;printf "%04d-%02d-%02dT%02d:%02d:%02d%+03d:%02d",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0],$o/60,$o%60;')
  csclassification="ci.aixcomputersystem"
  osclassification="ci.aixos"
  operatingsystem_osname="IBM AIX"
  computersystem_manufacturer="IBM"
  hostname=$(uname -n | cut -f1 -d'.')
  ciname="${hostname}"
  computersystem_fqdn=$(uname -n)

  lpar=$(uname -L | awk '{ print $2}')
  if [ "${lpar}" = "NULL" ]; then
    computersystem_virtual="false"
  else
    computersystem_virtual="true"
  fi

  operatingsystem_osversion=$(oslevel | cut -f1,2 -d.)
  OSLEVEL=$(oslevel -s)
  operatingsystem_servicepack="TL $(printf "%s" "${OSLEVEL}" | cut -f2 -d-) SP $(echo "${OSLEVEL}" | cut -f3 -d-)"
  operatingsystem_kernelversion="${OSLEVEL}"
  computersystem_swapmemsize=$(lsps -s | grep -v Total | sed 's/MB//' | awk '{ print $1 }')

  prtconf > prtconf.txt
  computersystem_model=$(grep '^System Model:' prtconf.txt | cut -f2 -d,)
  computersystem_model=$(grep '^System Model:' prtconf.txt | cut -f2 -d,)
  computersystem_serialnumber=$(grep '^Machine Serial Number:' prtconf.txt | awk -F ":" '{ print $2 }' |xargs)
  if test "${computersystem_serialnumber}" == "Not Available"; then
    computersystem_serialnumber=""
    printf '%s' "${computersystem_serialnumber}"
  fi
  computersystem_memorysize=$(grep '^Memory Size:' prtconf.txt | awk '{ print $3 }')
  computersystem_numcpus=$(lparstat -i | grep "Entitled Capacity " | grep -v Pool | awk '{print $4}')
  computersystem_cpucoresenabled=$(grep '^Number Of Processors:' prtconf.txt | awk '{ print $NF }')
  computersystem_numvirtualcpus=$(lparstat -i | grep "Online Virtual CPUs" | awk '{print $5}')
  computersystem_cpumode=$(lparstat -i | grep -w "Mode" | grep -v Pool | awk '{print $3}' | grep -v "Mode" | grep -v ":")
  computersystem_cputype=$(grep '^Processor Implementation Mode:' prtconf.txt | cut -d: -f2)
  if [ "${computersystem_cputype}" = "" ]; then
    computersystem_cputype=$(grep '^Processor Type:' prtconf.txt | cut -d: -f2 | sed 's/^ *//')$(grep '^Processor Clock Speed:' prtconf.txt | cut -d: -f2)
  else
    computersystem_cputype=$(grep '^Processor Implementation Mode:' prtconf.txt | cut -d: -f2 | sed 's/^ *//')$(grep '^Processor Clock Speed:' prtconf.txt | cut -d: -f2)
  fi

  operatingsystem_osmode=$(grep '^Kernel Type:' prtconf.txt | awk '{ print $NF }')

  {
    printf "\n\n Get AIX info \n"
    printf "Scan Time: %s\n" "$scantime"
    printf "Hostname: %s\n" "$hostname"
    printf "Computer System FQDN: \n%s\n" "$computersystem_fqdn"
    printf "Command: uname -L \n%s\n\n" "$( uname -L  2>&1)"
    printf "Command: uname -W \n%s\n\n" "$(uname -W 2>&1)"
    printf "Operating System OS level: \n%s\n" "$(oslevel | cut -f1,2 -d. 2>&1)"
    printf "Operating System Version: \n%s\n" "$(oslevel -s 2>&1)"
    printf "Computer System Swap Memory Size=\$(lsps -s): \n%s\n" "$(lsps -s 2>&1)"
    printf "Command: prtconf: \n%s\n\n" "$(cat prtconf.txt 2>&1)"
    printf "Command: lparstat -i: \n%s\n\n" "$(cat lparstat -i 2>&1)"
  } >> "$log_file"

  rm -f prtconf.txt
}

## @fn get_sunos_dependent_info()
## @brief Get OS information of SunOS architecture
get_sunos_dependent_info() {
    # Check if running on SunOS
    if [ "$(uname -s)" != "SunOS" ]; then
        echo "Error: This script is intended for SunOS systems only."
        exit 1
    fi

    # Ensure log_file variable is initialized
    if [ -z "${log_file}" ]; then
        echo "Error: log_file variable is not initialized."
        exit 1
    fi

    scantime=$(date +%Y-%m-%dT%H:%M:%S%:z)
    csclassification="ci.sunsparccomputersystem"
    osclassification="ci.solarisos"
    operatingsystem_osname="Solaris"
    computersystem_manufacturer="Oracle"
    hostname=$(uname -n | cut -f1 -d'.')
    ciname="${hostname}"
    computersystem_fqdn=$(uname -n)
    operatingsystem_osversion=$(uname -r | cut -f2 -d'.')
    operatingsystem_kernelversion=$(uname -v)

    # Extracting additional information
    computersystem_numcpus=$(psrinfo -p)
    computersystem_cpucoresenabled=$(kstat -m cpu_info | grep core_id | uniq | wc -l)
    computersystem_cputype=$(psrinfo -pv | head -1)
    computersystem_numvirtualcpus=$(psrinfo | wc -l)

    # Check for CPU mode
    if isainfo -kv | grep -q "64-bit"; then
        kernel_mode="64-bit"
    else
        kernel_mode="32-bit"
    fi

    computersystem_memorysize=$(prtconf | grep "Memory size" | awk '{print $3}')
    computersystem_swapmemsize=$(swap -s | awk '{print $2}' | sed 's/k$//')
    computersystem_model=$(uname -i)
    computersystem_serialnumber=$(hostid)

    # Check virtualization status
    if [ "$(virtinfo -a 2>/dev/null | grep -c 'Domain role: logical')" -gt 0 ]; then

        computersystem_virtual="True"
    elif [ "$(zonename)" != "global" ]; then
        computersystem_virtual="True"
    elif [ -x /usr/bin/xenstore-read ]; then
        computersystem_virtual="True"
    else
        computersystem_virtual="False"
    fi

    computersystem_timezone=$(date +%Z)
    computersystem_dns=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | xargs | sed 's/ /, /g')
    modelobject_contextip=$(ifconfig -a | grep inet | awk '{print $2}' | grep -v '127.0.0.1' | head -1)
    operatingsystem_servicepack="N/A"
    operatingsystem_osmode=$(isainfo -kv | head -1)


    {
        printf "\n\n Get SunOS info \n"
        printf "Scan time: %s\n" "$scantime"
        printf "Hostname: %s\n" "$hostname"
        printf "Operating System OS Version: %s\n" "$operatingsystem_osversion"
        printf "Hostid: \n%s\n" "$(hostid 2>&1)"
        printf "Command: prtconf -b \n%s\n\n" "$(prtconf -b 2>&1)"
        printf "Command: prtconf \n%s\n\n" "$(prtconf 2>&1)"
        printf "Command: prtdiag -v \n%s\n\n" "$(prtdiag -v 2>&1)"
        printf "Command: Psrinfo -p \n%s\n\n" "$(psrinfo -p 2>&1)"
        printf "Command: psrinfo -pv \n%s\n\n" "$(psrinfo -pv 2>&1)"
        printf "Command: isalist \n%s\n\n" "$(isalist 2>&1)"
        printf "Command: cat /etc/release \n%s\n\n" "$(cat /etc/release 2>&1)"
        if [ -x "/usr/platform/$(uname -i)/sbin/prtdiag" ]; then
            platform_path="/usr/platform/$(uname -i)/sbin/prtdiag"
            printf "Path %s: \n%s\n\n" "$platform_path" "$("$platform_path")"

        else
            printf "Path /usr/platform/%s/sbin/prtdiag does not exist or is not executable. Fetching system details using prtconf.\n\n" "$(uname -i)"
            prtconf
        fi
        printf "Command: swap -l \n%s\n\n" "$(swap -l 2>&1)"
        printf "Kernel Version: %s\n" "$operatingsystem_kernelversion"
        printf "Number of Physical CPUs: %s\n" "$computersystem_numcpus"
        printf "Number of Enabled CPU Cores: %s\n" "$computersystem_cpucoresenabled"
        printf "CPU Type: %s\n" "$computersystem_cputype"
        printf "Number of Virtual CPUs: %s\n" "$computersystem_numvirtualcpus"
        printf "CPU Mode: %s\n" "$computersystem_cpumode"
        printf "Memory Size (MB): %s\n" "$computersystem_memorysize"
        printf "Swap Memory Size (KB): %s\n" "$computersystem_swapmemsize"
        printf "Computer System Model: %s\n" "$computersystem_model"
        printf "Computer System Serial Number: %s\n" "$computersystem_serialnumber"
        printf "Is Virtual: %s\n" "$computersystem_virtual"
        printf "Timezone: %s\n" "$computersystem_timezone"
        printf "DNS: %s\n" "$computersystem_dns"
        printf "IP Address: %s\n" "$modelobject_contextip"
        printf "OS Mode: %s\n" "$operatingsystem_osmode"
    } >> "$log_file"
}

## @fn get_hpux_dependent_info()
## @brief Get OS information of HP-UX architecture
get_hpux_dependent_info() {
  scantime=$(date +%Y-%m-%dT%H:%M:%S%:z)
  csclassification="ci.hpuxcomputersystem"
  osclassification="ci.hpuxos"
  operatingsystem_osname="HP-UX"
  computersystem_manufacturer="HP"
  hostname=$(uname -n | cut -f1 -d'.')
  ciname="${hostname}"
  operatingsystem_osversion=$(uname -r)

  {
    printf "\n\n Get HP-UX info \n"
    printf "Hostname: %s\n" "$hostname"
    printf "Operating System OS Version: %s\n" "$operatingsystem_osversion"
    printf "Command: getconf MACHINE_SERIAL \n%s\n\n" "$(getconf MACHINE_SERIAL 2>&1)"
    printf "Command: getconf KERNEL_BITS \n%s\n\n" "$(getconf KERNEL_BITS 2>&1)"
    printf "Command: getconf HW_CPU_SUPP_BITS \n%s\n\n" "$(getconf HW_CPU_SUPP_BITS 2>&1)"
    printf "Command: getconf \n%s\n\n" "$(getconf 2>&1)"
    printf "Command: machinfo: \n%s\n\n" "$(machinfo 2>&1)"
    printf "Model: \n%s\n\n" "$(model 2>&1)"
    printf "Command: grep \"Physical:\" /var/adm/syslog/syslog.log \n%s\n\n" "$(grep "Physical:" /var/adm/syslog/syslog.log 2>&1)"
    printf "Command: ioscan -k \n%s\n\n" "$(ioscan -k 2>&1)"
    printf "Command: /usr/bin/arch -k \n%s\n\n" "$(/usr/bin/arch -k 2>&1)"
    printf "Command : uname -m \n%s\n\n" "$(uname -m 2>&1)"
    printf "Command: swlist HPUX*OE* \n%s\n\n" "$(swlist HPUX*OE* 2>&1)"
  } >> "$log_file"

}

## @fn get_other_dependent_info()
## @brief Get general information of Linux, not a specific distribution
get_other_dependent_info() {
  scantime=$(date +%Y-%m-%dT%H:%M:%S%:z)
  csclassification="ci.computersystem"
  osclassification="ci.os"
  operatingsystem_osname=${uname}
  operatingsystem_osversion=$(uname -r)
  hostname=$(uname -n | cut -f1 -d'.')
  ciname="${hostname}"

  {
    printf "\n\nGet other OS info \n"
    printf "Hostname: %s\n" "$hostname"
    printf "Operating System OS Version: %s\n" "$operatingsystem_osversion"
  } >> "$log_file"
}

## @fn print_os_results()
## @brief Call function according to the OS of the host
get_os_dependent_info() {
  if [ "${uname}" = "Linux" ]; then
    get_linux_dependent_info
  elif [ "${uname}" = "AIX" ]; then
    get_aix_dependent_info
  elif [ "${uname}" = "SunOS" ]; then
    get_sunos_dependent_info;
  elif [ "${uname}" = "HP-UX" ]; then
    get_hpux_dependent_info
  else
    get_other_dependent_info
  fi
}

## @fn print_os_results()
## @brief Print vars that contains OS values found on host
print_os_results(){
  printf "Print OS results \n" >> "$log_file"

  touch "$output_file"
  {
    printf "{ \"computersystem\": { "
    printf "\"classification\": \"%s\"" "${csclassification}"
    printf ", \"hostname\": \"%s\"" "${hostname}"
    printf ", \"cinum\": \"%s\"" "${ciname}"
    printf ", \"ciname\": \"%s\"" "${ciname}"
    printf ", \"computersystem_name\": \"%s\"" "${hostname}"
    printf ", \"computersystem_fqdn\": \"%s\"" "${computersystem_fqdn}"
    printf ", \"computersystem_virtual\": \"%s\"" "${computersystem_virtual}"
    printf ", \"computersystem_cputype\": \"%s\"" "${computersystem_cputype}"
    printf ", \"computersystem_numcpus\": \"%s\"" "${computersystem_numcpus}"
    printf ", \"computersystem_numvirtualcpus\": \"%s\"" "${computersystem_numvirtualcpus}"
    printf ", \"computersystem_cpumode\": \"%s\"" "${computersystem_cpumode}"
    printf ", \"computersystem_cpucoresenabled\": \"%s\"" "${computersystem_cpucoresenabled}"
    printf ", \"computersystem_memorysize\": \"%s\"" "${computersystem_memorysize}"
    printf ", \"computersystem_swapmemsize\": \"%s\"" "${computersystem_swapmemsize}"
    printf ", \"computersystem_manufacturer\": \"%s\"" "${computersystem_manufacturer}"
    printf ", \"computersystem_serialnumber\": \"%s\"" "${computersystem_serialnumber}"
    printf ", \"computersystem_model\": \"%s\"" "${computersystem_model}"
    printf ", \"computersystem_timezone\": \"%s\"" "${computersystem_timezone}"
    printf ", \"computersystem_dns\": \"%s\"" "${computersystem_dns}"
    printf ", \"modelobject_contextip\": \"%s\"" "${modelobject_contextip}"
    printf ", \"operating_system\": { "
    printf "\"classification\": \"%s\"" "${osclassification}"
    printf ", \"inverse_relation\": \"runson\""
    printf ", \"cinum\": \"%s\"" "${ciname}:OS"
    printf ", \"ciname\": \"%s\"" "${ciname}:OS"
    printf ", \"operatingsystem_osname\": \"%s\"" "${operatingsystem_osname}"
    printf ", \"operatingsystem_osversion\": \"%s\"" "${operatingsystem_osversion}"
    printf ", \"operatingsystem_servicepack\": \"%s\"" "${operatingsystem_servicepack}"
    printf ", \"operatingsystem_osmode\": \"%s\"" "${operatingsystem_osmode}"
    printf ", \"operatingsystem_kernelversion\": \"%s\"" "${operatingsystem_kernelversion}"
    printf " } "
  } >> "$output_file"

}

## @fn print_disks_info()
## @brief Retrieve and print disks information
print_disks_info() {
  printf "Print disks results \n" >> "$log_file"

  if [ "${uname}" = "Linux" ]; then
    df -mlTP | sort | awk -v CINAME="${ciname}" '
      BEGIN {
        ORS = "";
        printf ", \"filesystems\": [ "
      }
      /^Filesystem/ {next}
      {
        if($2 != "tmpfs" && $2 != "devtmpfs") {
          printf "%s{\"classification\": \"ci.filesystem\", \"relation\": \"contains\", \"cinum\": \"%s:%s\", \"ciname\": \"%s:%s\", \"filesystem_type\": \"%s\", \"filesystem_capacity\": \"%s\", \"filesystem_availablespace\": \"%s\", \"filesystem_mountpoint\": \"%s\"}", separator, CINAME, $1, CINAME, $7, $2, $3, $5, $7
          separator = ", "
        }
      }
      END {
        printf " ] "
      }
    ' >> "$output_file"
    printf "df -mlTP | sort: \n%s\n" "$(df -mlTP | sort 2>&1)" >> "$log_file"

  elif [ "${uname}" = "AIX" ]; then
    df -mP | sort | awk -v CINAME="${ciname}" '
      BEGIN {
        ORS = "";
        printf ", \"filesystems\": [ "
      }
      /^Filesystem/ {next}
      /\proc / {next}
      {
        printf "%s{\"classification\": \"ci.filesystem\", \"relation\": \"contains\", \"cinum\": \"%s:%s\", \"ciname\": \"%s:%s\", \"filesystem_type\": \"\", \"filesystem_capacity\": \"%d\", \"filesystem_availablespace\": \"%d\", \"filesystem_mountpoint\": \"%s\"}", separator, CINAME, $1, CINAME, $6, $2, $4, $6
        separator = ", "
      }
      END {
        printf " ] "
      }
    ' >> "$output_file"
    printf "df -mP | sort: \n%s\n" "$(df -mP | sort 2>&1)" >> "$log_file"

  elif [ "${uname}" = "SunOS" ]; then
    df -k | sort | nawk -v CINAME="${ciname}" '
      BEGIN {
          ORS = "";
          separator = "";
          printf ", \"filesystems\": [ "
      }
      /^Filesystem/ { next }
      # Exclude swap filesystems for Solaris
      $3 ~ /^swap$/ { next }
      {
          printf "%s{\"classification\": \"ci.filesystem\", \"relation\": \"contains\", \"cinum\": \"%s:%s\", \"ciname\": \"%s:%s\", \"filesystem_type\": \"%s\", \"filesystem_capacity\": \"%s\", \"filesystem_availablespace\": \"%s\", \"filesystem_mountpoint\": \"%s\"}", separator, CINAME, $1, CINAME, $6, $3, $4, $5, $6;
          separator = ", ";
      }
      END {
          printf " ] "
      }
    ' >> "$output_file"
    printf "df -k | sort: \n%s\n" "$(df -k | sort 2>&1)" >> "$log_file"

  else
    df -mlP | sort | awk -v CINAME="${ciname}" '
      BEGIN {
        ORS = "";
        printf ", \"filesystems\": [ "
      }
      /^Filesystem/ {next}
      /\proc / {next}
      {
        printf "%s{\"classification\": \"ci.filesystem\", \"relation\": \"contains\", \"cinum\": \"%s:%s\", \"ciname\": \"%s:%s\", \"filesystem_type\": \"\", \"filesystem_capacity\": \"%d\", \"filesystem_availablespace\": \"%d\", \"filesystem_mountpoint\": \"%s\"}", separator, CINAME, $1, CINAME, $6, $2, $4, $6
        separator = ", "
      }
      END {
        printf " ] "
      }
    ' >> "$output_file"
    printf "df -mlP | sort: \n%s\n" "$(df -mlP | sort 2>&1)" >> "$log_file"
  fi
}

## @fn print_network_info()
## @brief Retrive and print network information
print_network_info() {
  printf "Print network results \n"  >> "$log_file"
  # IPs
  if [ "${uname}" = "Linux" ]; then
    if [ -x /usr/sbin/ip ]; then
      ip addr | awk -v CINAME="${ciname}" '
        BEGIN {
          ORS = "";
          printf ", \"interfaces\": [ "
        }
        /valid_lft/ {next}
        {
          if(/^[0-9]/) {
            if(separator2 == ", ") {
               printf " ] } ";
               separator2 = "";
            }
            split($2,i,":");
            interface=i[1];
            if($0 ~ /,UP,/) {
              state="UP";
            } else if ($0 ~ /,DOWN,/) {
              state="DOWN";
            } else {
              state="UNKNOWN";
            }
          } else if(/^\s+link\//) {
            split($1, t, "/");
            type=t[2] == "ether" ? "Ethernet" : t[2];
            mac=$2;
          } else if (/^\s+inet/) {
            if(type != "loopback") {
              split($2, ip, "/");
              mask = ip[2] == "" ? "32" : ip[2];
              ipaddress = ip[1] == "" ? "N/A" : ip[1]
              state = state == "" ? "N/A" : state
              type = type == "" ? "N/A" : type
              mac = mac == "" ? "N/A" : mac
              ifname = $NF == "" ? "N/A" : $NF
              printf "%s{ \"classification\": \"ci.ipinterface\", \"relation\": \"contains\", \"cinum\": \"%s:%s:%s\", \"ciname\": \"%s:%s\", \"networkinterface_ipaddress\": \"%s\", \"networkinterface_netmask\": \"/%s\", \"networkinterface_interfacename\": \"%s\", \"networkinterface_adminstate\": \"%s\", \"networkinterface_ianainterfacetype\": \"%s\", \"networkinterface_physicaladdress\": \"%s\" }", separator, CINAME, ifname, ipaddress, CINAME, ipaddress, ipaddress, mask, ifname, state, type, mac;
              separator = ", ";
            }
          }
        }
        END {
          printf " ] "
        }
      ' >> "$output_file"
      printf "ip addr: \n%s\n" "$(ip addr 2>&1)" >> "$log_file"

    else
      ifconfig -a | sed -e 's/inet\ end\.:\ /inet addr:/' | awk -v CINAME="${ciname}" '
        BEGIN {
          ORS = "";
          printf ", \"interfaces\": [ "
        }
        {
          if($2 == "Link") {
            interface = $1
            split($3, t, ":")
            type = t[2]
            mac = $5
          } else if($1 == "inet" && interface != "lo") {
            split($2, i, ":")
            ip = i[2]
            split($4, m, ":")
            mask = m[2]
            printf "%s{ \"classification\": \"ci.ipinterface\", \"relation\": \"contains\", \"cinum\": \"%s:%s:%s\", \"ciname\": \"%s:%s\", \"networkinterface_ipaddress\": \"%s\", \"networkinterface_netmask\": \"%s\", \"networkinterface_interfacename\": \"%s\", \"networkinterface_adminstate\": \"%s\", \"networkinterface_ianainterfacetype\": \"%s\", \"networkinterface_physicaladdress\": \"%s\" }", separator, CINAME, interface, ip, CINAME, ip, ip, mask, interface, state, type, mac;
            separator = ", "
          }
        }
        END {
          printf " ] "
        }' >> "$output_file"

      printf "Command: ifconfig -a: \n%s\n\n" "$(ifconfig -a 2>&1)" >> "$log_file"
    fi

  elif [ "${uname}" = "AIX" ]; then

    ifconfig -a | awk -v CINAME="${ciname}" '
      BEGIN {
        ORS = "";
        printf ", \"interfaces\": [ "
      }
      /tcp_sendspace/ {next}
      {
        if(/^en/) {
          if(separator2 == ", ") {
             printf " ] } "
             separator2 = "";
          }
          split($1, i, ":");
          interface=i[1];
  		split($0, s1, "<");
  		split(s1[2], s2, ",");
  		state=s2[1];
        } else if (/inet/) {
  	    if(interface != "") {
  		  netmask=sprintf("%d.%d.%d.%d", "0x" substr($4, 3, 2), "0x" substr($4, 5, 2), "0x" substr($4, 7, 2), "0x" substr($4, 9, 2));
            printf "%s{ \"classification\": \"ci.ipinterface\", \"relation\": \"contains\", \"cinum\": \"%s:%s:%s\", \"ciname\": \"%s:%s\", \"networkinterface_ipaddress\": \"%s\", \"networkinterface_netmask\": \"%s\", \"networkinterface_interfacename\": \"%s\", \"networkinterface_adminstate\": \"%s\", \"networkinterface_ianainterfacetype\": \"%s\", \"networkinterface_physicaladdress\": \"%s\" }", separator, CINAME, interface, $2, CINAME, $2, $2, netmask, interface, state, "Ethernet", "";
            separator = ", ";
  		  interface="";
  		}
        }
      }
      END {
        printf " ] "
      }
    ' >> "$output_file"
    printf "Command: ifconfig -a \n%s\n\n" "$(ifconfig -a 2>&1)" >> "$log_file"

  elif [ "${uname}" = "SunOS" ]; then
      ifconfig -a | awk -v CINAME="${ciname}" '
        BEGIN {
          ORS = "";
          printf ", \"interfaces\": [ "
          separator = "";
        }
        {
          # Skipping loopback interfaces
          if ($1 ~ /^lo[0-9]+:/ || $1 == "lo0:") {
              next;
          }
          # Checking for the presence of interface and its state (UP or DOWN)
          if ($1 ~ /:/ && !($1 ~ /^lo/)) {
            if (separator == ", ") {
              printf ", "
            }
            split($1, interfaceSplit, ":");
            interfaceName = interfaceSplit[1];
            currentState = ($5 == "UP") ? "UP" : "DOWN";
            currentType = ($3 == "mtu") ? "Ethernet" : $3;
          }
          # Checking for IP address and netmask
          else if ($1 == "inet") {
            ipAddress = $2;
            netMask = $4;  # Note: Netmask might need further processing to get in desired format
            printf "%s{ \"classification\": \"ci.ipinterface\", \"relation\": \"contains\", \"cinum\": \"%s:%s:%s\", \"ciname\": \"%s:%s\", \"networkinterface_ipaddress\": \"%s\", \"networkinterface_netmask\": \"%s\", \"networkinterface_interfacename\": \"%s\", \"networkinterface_adminstate\": \"%s\", \"networkinterface_ianainterfacetype\": \"%s\", \"networkinterface_physicaladdress\": \"%s\" }", separator, CINAME, interfaceName, ipAddress, CINAME, ipAddress, ipAddress, netMask, interfaceName, currentState, currentType, "";
            separator = ", ";
          }
        }
        END {
          printf " ] "
        }
      ' >> "$output_file"
      printf "Command: ifconfig -a \n%s\n\n" "$(ifconfig -a 2>&1)" >> "$log_file"

  else
    printf "Command: ifconfig -a \n%s\n\n" "$(ifconfig -a 2>&1)" >> "$log_file"
  fi
}

## @fn parse_subsystem_information()
## @brief Will get the subsystem information found on txt file and parse to JSON then print the result
parse_subsystem_information(){
  printf "Print subsystems results \n" >> "$log_file"

  if [ -r "${sss_file}" ] ; then
    tr -d '\r' < "${sss_file}" | sort -u | grep -v "SUBSYSTEM_TYPE=OSL" | awk -v HOST="${ciname}" '
      BEGIN {
        FS=";";
        OFS=",";
        printf ", \"subsystems\": [ "
      }
      /SUBSYSTEM_INSTANCE=NO/ { next };
      {
        split($5, i, "=");
        instance = i[2];
        split($6, t, "=");
        type = t[2];
        classification = "";  # default classification
        if (type == "HAN") {
            classification = "CI.SAPHANAINSTANCE";
        }
        split($7, v, "=");
        version = v[2];
        split($8, e, "=");
        edition = e[2];
        split($9, f, "=");
        fixpack = f[2];
        split($10, p, "=");
        instpash = p[2];
        split($11, d, "=");
        dbname = d[2];
        split($16, o, "=");
        port = o[2];
        if(type == lasttype && instance == lastinstance && (type == "DB2" || type == "IFX" || type == "MSL" || type == "MYL" || type == "ORA" || type == "SYB")) {
          printf ", { \"classification\": \"%s\", \"relation\": \"contains\", \"cinum\": \"%s:%s:%s:%s\", \"ciname\": \"%s:%s:%s\", \"database_name\": \"%s\" }", classification, HOST, type, instance, dbname, HOST, instance, dbname, dbname;

        } else {
          printf "%s{ \"classification\": \"%s\", \"inverse_relation\": \"runson\", \"cinum\": \"%s:%s:%s\", \"ciname\": \"%s:%s\", \"appserver_productname\": \"%s\", \"appserver_productversion\": \"%s\", \"appserver_servicepack\": \"%s\", \"appserver_vendorname\": \"\", \"type\": \"%s\", \"installpath\": \"%s\", \"port\": \"%s\" ", separator, classification, HOST, type, instance, HOST, instance, edition, version, fixpack, type, instpath, port;

          if(type == "DB2" || type == "IFX" || type == "MSL" || type == "MYL" || type == "ORA" || type == "SYB") {
            printf ", \"databases\": [ { \"classification\": \"\", \"relation\": \"contains\", \"cinum\": \"%s:%s:%s:%s\", \"ciname\": \"%s:%s:%s\", \"database_name\": \"%s\" }", HOST, type, instance, dbname, HOST, instance, dbname, dbname;
            finishdb = 1;
            lasttype = type;
            lastinstance = instance;
            separator = "] }, ";

          } else {
            printf "}";
            separator = ", ";
            finishdb = 0;
          }
        }
      }
      END {
        if(finishdb) {
          printf "] } ] ";
        } else {
          printf " ] ";
        }
      }
    ' >> "$output_file"
    printf "Command: grep -v SUBSYSTEM_INSTANCE=NO $sss_file \n%s\n\n" "$(grep -v SUBSYSTEM_INSTANCE=NO "$sss_file" 2>&1)" >> "$log_file"
  fi
}

## @fn print_scan_time()
## @brief Will get the subsystem information found on txt file and parse to JSON
print_scan_time() {
  printf "Print scan time \n" >> "$log_file"
  printf "}, \"pluspcustomer\": \"\", \"change\": \"\", \"scan_time\": \"%s\", \"jsonversion\": \"1\" }" "${scantime}" >> "$output_file"
}

main() {
  check_params
  export_path
  get_computer_system_info
  get_architecture_independent_info
  get_os_dependent_info
  print_os_results
  print_disks_info
  print_network_info
  parse_subsystem_information
  print_scan_time
  printf "Scan finished \n" >> "$log_file"
  printf '{"msg": "Log can be found on computersystem.log inside results folder"}'
}

main
