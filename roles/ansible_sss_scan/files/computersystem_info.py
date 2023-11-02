#!/usr/bin/env python3
"""
This module provides functionalities to parse subsystem information from
a given text file and outputs the result in JSON format.
"""

import datetime
import json
import sys
import os
import socket
from pathlib import Path
import subprocess


def get_computer_system_info():
    """Fetch and return various computer system information in dictionary format."""

    info_dict = {}

    info_dict["computersystem_timezone"] = os.popen("date +%Z").read().strip()

    # Read nameservers from resolv.conf
    with Path("/etc/resolv.conf").open(encoding='utf-8') as file:
        info_dict["computersystem_dns"] = ",".join(
            line.split()[1] for line in file if line.startswith("nameserver"))

    ipcmdb_path = Path("results/ipcmdb.csv")
    if ipcmdb_path.exists():
        with ipcmdb_path.open(encoding='utf-8') as file:
            info_dict["modelobject_contextip"] = list(
                file)[-1].split(',')[1].strip()

    return info_dict


def run_command(cmd):
    """Execute a shell command and return its output as a string."""
    try:
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                shell=True, universal_newlines=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as error:
        raise ValueError(
            f"Command '{cmd}' failed with error: {error.stderr}") from error


def get_cpu_info() -> dict:
    """Collect CPU related information."""
    info = {
        'computersystem_cputype': "N/A",
        'computersystem_cpucoresenabled': "N/A",
        'computersystem_numcpus': "N/A"
    }

    try:
        cmd_output = run_command(
            "grep 'model name' /proc/cpuinfo | head -n 1").strip()
        info['computersystem_cputype'] = cmd_output.split(
            ":")[1].strip() if cmd_output else "N/A"

        cmd_output = run_command("grep -c '^processor' /proc/cpuinfo").strip()
        info['computersystem_cpucoresenabled'] = cmd_output

        cmd_output = run_command(
            "grep '^physical id' /proc/cpuinfo | sort -u | wc -l").strip()
        info['computersystem_numcpus'] = cmd_output
    except Exception as e:
        # In case of any error, the values remain "N/A"
        print(f"Error while collecting CPU info: {str(e)}")

    return info


def get_memory_info() -> dict:
    """Collect memory related information."""
    info = {
        "computersystem_memorysize": "N/A",
        "computersystem_swapmemsize": "N/A"
    }

    try:
        mem_total = run_command("grep MemTotal /proc/meminfo").strip()
        info["computersystem_memorysize"] = str(
            int(mem_total.split()[1]) // 1024) if mem_total else "N/A"

        swap_total = run_command("grep SwapTotal /proc/meminfo").strip()
        info["computersystem_swapmemsize"] = str(
            int(swap_total.split()[1]) // 1024) if swap_total else "N/A"
    except Exception as e:
        # In case of any error, the values remain "N/A"
        print(f"Error while collecting memory info: {str(e)}")

    return info


def get_system_info() -> dict:
    """Collect system related information."""
    info = {
        "computersystem_manufacturer": "N/A",
        "computersystem_serialnumber": "N/A",
        "computersystem_model": "N/A"
    }

    try:
        manufacturer = run_command("cat /sys/class/dmi/id/sys_vendor").strip()
        if not manufacturer:
            raise ValueError("Manufacturer info not found")
        info["computersystem_manufacturer"] = manufacturer
    except Exception:
        try:
            manufacturer = run_command(
                "lshw -class system | grep 'vendor:' | awk '{print $2}'").strip()
            info["computersystem_manufacturer"] = manufacturer if manufacturer else "N/A"
        except Exception as error:
            print(f"Error while collecting manufacturer info: {str(error)}")

    try:
        serial_number = run_command(
            "cat /sys/class/dmi/id/product_serial").strip()
        if not serial_number:
            raise ValueError("Serial number not found")
        info["computersystem_serialnumber"] = serial_number
    except Exception:
        try:
            serial_number = run_command(
                "lshw -class system | grep 'serial:' | awk '{print $2}'").strip()
            info["computersystem_serialnumber"] = serial_number if serial_number else "N/A"
        except Exception as error:
            print(f"Error while collecting serial number info: {str(error)}")

    try:
        model = run_command("cat /sys/class/dmi/id/product_name").strip()
        if not model:
            raise ValueError("Model info not found")
        info["computersystem_model"] = model
    except Exception:
        try:
            model = run_command(
                "lshw -class system | grep 'product:' | awk '{print $2}'").strip()
            info["computersystem_model"] = model if model else "N/A"
        except Exception as error:
            print(f"Error while collecting model info: {str(error)}")

    return info


def get_timezone_and_dns() -> dict:
    """Collect timezone and DNS information."""
    info = {}
    info["computersystem_timezone"] = run_command("date +%z").strip()
    dns_info = run_command("cat /etc/resolv.conf | grep nameserver").strip()
    info["computersystem_dns"] = ",".join(
        line.split()[1] for line in dns_info.splitlines())
    return info


def get_ip_info() -> dict:
    """Collect IP related information."""
    info = {}
    ip_info = run_command("hostname -I | awk '{print $1}'").strip()
    info["modelobject_contextip"] = ip_info if ip_info else "N/A"
    return info


def collect_linux_info():
    """
    Collect comprehensive Linux system information.

    :return: dict containing the Linux system information
    """
    linux_info = {}
    linux_info.update(get_cpu_info())
    linux_info.update(get_memory_info())
    linux_info.update(get_system_info())
    linux_info.update(get_timezone_and_dns())
    linux_info.update(get_ip_info())

    return linux_info


def get_architecture_independent_info():
    """Fetch and return architecture-independent
        system information in dictionary format.
    """
    info_dict = {}

    # Fetching Memory and Swap information using 'free' command
    mem_output = run_command("free -m").splitlines()
    mem_info = [int(x) for x in mem_output[1].split() if x.isdigit()]
    swap_info = [int(x) for x in mem_output[2].split() if x.isdigit()]

    info_dict["computersystem_memorysize"] = mem_info[1]  # total memory in MB
    info_dict["computersystem_swapmemsize"] = swap_info[0]  # total swap in MB

    # Check for hypervisor
    cpu_info = run_command("cat /proc/cpuinfo")
    if "hypervisor" in cpu_info:
        if os.path.exists("/etc/oracle-release"):
            oracle_vm_check = run_command("cat /etc/oracle-release")
            info_dict["computersystem_virtual"] = "Oracle VM Server" not in oracle_vm_check
        else:
            info_dict["computersystem_virtual"] = True
    else:
        info_dict["computersystem_virtual"] = False

    uname_info = os.uname()
    info_dict["operatingsystem_osmode"] = uname_info.machine
    info_dict["operatingsystem_kernelversion"] = uname_info.release

    return info_dict


def get_current_time() -> str:
    """Return the current time in ISO format."""
    return datetime.datetime.now().isoformat()


def get_hostname() -> str:
    """Retrieve the hostname of the system."""
    return run_command("uname -n").strip().split('.')[0]


def get_fqdn() -> str:
    """Retrieve the Fully Qualified Domain Name of the system."""
    return run_command("hostname -f").strip()


def file_exists(file_path: str) -> bool:
    """Check if the given file path exists."""
    return os.path.isfile(file_path)


def get_os_details(os_file_command_mapping: dict) -> tuple:
    """Retrieve the OS name and version using the given command mapping."""
    for file_path, commands in os_file_command_mapping.items():
        if file_exists(file_path):
            # Debugging statement for diagnosis
            print(f"Executing command: {commands[0]} for file: {file_path}")

            os_name = None
            os_version = None

            if commands[0]:
                os_name = run_command(commands[0]).strip()
            if commands[1]:
                os_version = run_command(commands[1]).strip()

            return os_name, os_version
    return "Linux", None


def log_linux_info(log_file_path: str, info_dict: dict):
    """Log Linux details to the specified file."""
    with open(log_file_path, 'a', encoding='utf-8') as log_file:
        log_file.write("\n\nGet Linux info \n")
        log_file.write(f"Scan Time: \n{info_dict['scantime']}\n")
        log_file.write(f"Hostname: {info_dict['hostname']}\n")
        log_file.write(
            f"Command: ls /etc/*release \n{run_command('ls /etc/*release')}\n")
        log_file.write(
            f"Command: cat /etc/*release \n{run_command('cat /etc/*release')}\n")


def get_linux_dependent_info(log_file_path: str) -> dict:
    """Retrieve Linux distribution-specific information."""
    info_dict = {
        "scantime": get_current_time(),
        "hostname": get_hostname(),
        "computersystem_fqdn": get_fqdn(),
        "csclassification": "ci.linuxcomputersystem",
        "osclassification": "ci.linuxos"

    }

    # Mapping of file paths to commands for determining OS name and version
    os_file_command_mapping = {
        "/etc/oracle-release": (
            "head -1 /etc/oracle-release | sed 's/ release.*//g'",
            "head -1 /etc/oracle-release | "
            "sed -rn 's/.*release ([0-9\\.]*).*/\\1/p' | cut -f1-2 -d."
        ),
        "/etc/redhat-release": (
            "head -1 /etc/redhat-release | sed 's/ release.*//g'",
            "head -1 /etc/redhat-release | "
            "sed -rn 's/.*release ([0-9\\.]*).*/\\1/p' | cut -f1-2 -d."
        ),
        "/etc/fedora-release": (
            "head -1 /etc/fedora-release | sed 's/ release.*//g'",
            "head -1 /etc/fedora-release | "
            "sed -rn 's/.*release ([0-9\\.]*).*/\\1/p' | cut -f1-2 -d."
        ),
        "/etc/SuSE-release": (
            "head -1 /etc/SuSE-release | cut -f1-4 -d' '",
            "grep '^VERSION' /etc/SuSE-release | awk '{print $3}'"
        ),
        "/etc/lsb-release": (
            "grep ^DISTRIB_ID= /etc/lsb-release | cut -d= -f2 | sed s/\"//g",
            "grep ^DISTRIB_RELEASE= /etc/lsb-release | "
            "cut -d= -f2 | cut -d'.' -f1 | sed s/\"//g"
        ),
        "/etc/debian_version": ("echo 'Debian'", "cut -d'.' -f1 /etc/debian_version"),
        "/etc/system-release": ("head -1 /etc/system-release", None),
        "/etc/pgp-release": (
            "echo 'Symantec Encryption Server'",
            "cut -d' ' -f1 /etc/oem-release"
        ),
        "/etc/os-release": (
            "awk -F= '/^NAME=/ { gsub(/\"/, \"\", $2); print $2 }' /etc/os-release",
            "awk -F= '/^VERSION=/ { gsub(/\"/, \"\", $2); print $2 }' /etc/os-release"
        )
    }

    info_dict["operatingsystem_osname"], info_dict["operatingsystem_osversion"] = get_os_details(
        os_file_command_mapping)

    log_linux_info(log_file_path, info_dict)

    return info_dict


def fetch_scantime():
    """Return system scan time."""
    command = (
        "perl -MTime::Local -e '@t=localtime(time);$o=(timegm(@t)-timelocal(@t))/60;"
        "printf \"%04d-%02d-%02dT%02d:%02d:%02d%+03d:%02d\",$t[5]+1900,$t[4]+1,$t[3],"
        "$t[2],$t[1],$t[0],$o/60,$o%60;'"
    )
    return subprocess.getoutput(command)


def fetch_hostname():
    """Return system hostname."""
    return subprocess.getoutput("uname -n | cut -f1 -d'.'")


def fetch_fqdn():
    """Return system fully qualified domain name."""
    return subprocess.getoutput("uname -n")


def fetch_virtualization():
    """Determine if system is virtualized."""
    lpar = subprocess.getoutput("uname -L | awk '{ print $2}'")
    return "true" if lpar != "NULL" else "false"


def fetch_os_version():
    """Return operating system version."""
    return subprocess.getoutput("oslevel | cut -f1,2 -d.")


def fetch_os_level():
    """Return system OS level."""
    return subprocess.getoutput("oslevel -s")


def fetch_swap_memory():
    """Return swap memory size."""
    return subprocess.getoutput(
        "lsps -s | grep -v Total | sed 's/MB//' | awk '{ print $1 }'"
    )


def fetch_prtconf_data():
    """Fetch system configuration data using 'prtconf'."""
    return subprocess.getoutput("prtconf")


def fetch_computer_system_info(prtconf_data):
    """Fetch computer system-related information."""
    model = [line.split(': ')[1] for line in prtconf_data.splitlines()
             if 'System Model:' in line][0]
    serial_number = [line.split(': ')[1].strip() for line in prtconf_data.splitlines()
                     if 'Machine Serial Number:' in line][0]
    memory_size = [line.split(' ')[2] for line in prtconf_data.splitlines()
                   if 'Memory Size:' in line][0]

    return model, serial_number, memory_size


def fetch_cpu_info(prtconf_data):
    """Fetch CPU related information."""

    sysname = os.uname().sysname

    if sysname == "AIX":
        numcpus = subprocess.getoutput(
            "lparstat -i | grep 'Entitled Capacity ' | grep -v Pool | awk '{print $4}'"
        )

        computersystem_numvirtualcpus = subprocess.getoutput(
            "lparstat -i | grep 'Online Virtual CPUs' | awk '{print $5}'"
        )

        cpumode = subprocess.getoutput(
            "lparstat -i | grep -w 'Mode' | grep -v Pool | awk '{print $3}' | "
            "grep -v 'Mode' | grep -v ':'"
        )
    elif sysname == "Linux":
        # This will give the number of CPUs (could be cores or threads)
        numcpus = os.cpu_count()
        # In Linux context, virtual CPUs are equivalent to total CPUs
        computersystem_numvirtualcpus = numcpus
        cpumode = "N/A"  # You can update this if you have a way to fetch the CPU mode for Linux

    cpu_cores_list = [line.split(
        ' ')[-1] for line in prtconf_data.splitlines() if 'Number Of Processors:' in line]
    cpucoresenabled = cpu_cores_list[0] if cpu_cores_list else "Unknown"

    if 'Processor Implementation Mode:' in prtconf_data:
        cputype = (
            subprocess.getoutput(
                "grep '^Processor Implementation Mode:' prtconf.txt | cut -d: -f2 | sed 's/^ *//'"
            )
            + subprocess.getoutput(
                "grep '^Processor Clock Speed:' prtconf.txt | cut -d: -f2"
            )
        )
    else:
        cputype = (
            subprocess.getoutput(
                "grep '^Processor Type:' prtconf.txt | cut -d: -f2 | sed 's/^ *//'"
            )
            + subprocess.getoutput(
                "grep '^Processor Clock Speed:' prtconf.txt | cut -d: -f2"
            )
        )
    return numcpus, cpucoresenabled, computersystem_numvirtualcpus, cpumode, cputype


def fetch_os_mode(prtconf_data):
    """Fetch the OS mode."""
    return [line.split(' ')[-1] for line in prtconf_data.splitlines() if 'Kernel Type:' in line][0]


def get_linux_disks(ciname: str) -> list:
    """
    Retrieve Linux disk information.
    """
    output = run_command("df -mlTP | sort")
    lines = output.split("\n")[1:]
    filesystems = []

    for line in lines:
        parts = line.split()

        # Check if there are fewer than 7 columns in the line
        if len(parts) < 7:
            continue  # Skip the line if it does not have enough parts

        # Skip lines where the filesystem type is 'tmpfs' or 'devtmpfs'
        if parts[1] in ("tmpfs", "devtmpfs"):
            continue

        # Skip lines that have non-integer values for capacity and available space
        try:
            int(parts[2])  # filesystem_capacity
            int(parts[4])  # filesystem_availablespace
        except ValueError:
            continue

        filesystems.append({
            "classification": "ci.filesystem",
            "relation": "contains",
            "cinum": f"{ciname}:{parts[0]}",
            "ciname": f"{ciname}:{parts[6]}",
            "filesystem_type": parts[1],
            "filesystem_capacity": parts[2],
            "filesystem_availablespace": parts[4],
            "filesystem_mountpoint": parts[6]
        })

    return filesystems


def get_disks_info(ciname: str, uname: str) -> list:
    """
    Retrieve disk information based on the detected operating system.

    Args:
    - ciname (str): Hostname.
    - uname (str): System name.

    Returns:
    list: A list containing the disk information.
    """
    filesystems = []

    if uname == "Linux":
        filesystems = get_linux_disks(ciname)
    elif uname == "AIX":
        filesystems = get_aix_disks(ciname)
    elif uname == "SunOS":
        filesystems = get_sunos_disks(ciname)

    return filesystems


def get_linux_network_info(hostname: str) -> list:
    """Returns network interface details for a Linux system."""

    env = os.environ.copy()
    env['PATH'] = "/usr/sbin:/sbin:" + env['PATH']

    interfaces = []

    result = subprocess.run(['which', 'ip'], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, env=env, universal_newlines=True, check=False)

    if result.returncode == 0:
        result = subprocess.run(['ip', 'addr'], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, env=env, universal_newlines=True, check=False)
        output = result.stdout
        current_interface = None
        for line in output.splitlines():
            if 'link/' in line:
                # Initialize the details dictionary here.
                details = {}
                current_interface = line.split()[1]
                parts = line.split()

                # Find the MAC address after 'link/'
                mac_address = None
                for idx, part in enumerate(parts):
                    if 'link/' in part:
                        mac_address = parts[idx + 1]
                        break
                if mac_address:
                    details["networkinterface_physicaladdress"] = mac_address
            # Adding a space after inet ensures we're checking for IPv4
            elif line.strip().startswith('inet ') and 'loopback' not in line:
                fields = line.strip().split()
                address, netmask = fields[1].split('/')
                details["networkinterface_ipaddress"] = address
                details["networkinterface_netmask"] = "/" + netmask
                details["networkinterface_interfacename"] = current_interface
                details["cinum"] = f"{hostname}:{details['networkinterface_interfacename']}:{address}"
                details["ciname"] = f"{hostname}:{address}"
                details["classification"] = "ci.ipinterface"
                details["relation"] = "contains"
                details["networkinterface_adminstate"] = "UP"
                # Hardcoded for the purpose of the example. Adjust accordingly.
                details["networkinterface_ianainterfacetype"] = "Ethernet"
                interfaces.append(details)
    else:
        result = subprocess.run(['ifconfig', '-a'], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, env=env, universal_newlines=True, check=False)
        output = result.stdout
        current_interface = None
        for line in output.splitlines():
            if "Link encap" in line:
                details = {}
                current_interface = line.split()[0]
                details["networkinterface_physicaladdress"] = line.split()[-1]
            elif "inet addr" in line and current_interface:
                ip_data = line.split()
                ip_address = ip_data[1].split(":")[1]
                mask = ip_data[3].split(":")[1]
                details["networkinterface_ipaddress"] = ip_address
                details["networkinterface_netmask"] = mask
                details["networkinterface_interfacename"] = current_interface
                details["cinum"] = f"{hostname}:{current_interface}:{ip_address}"
                details["ciname"] = f"{hostname}:{ip_address}"
                details["classification"] = "ci.ipinterface"
                details["relation"] = "contains"
                details["networkinterface_adminstate"] = "UP"
                details["networkinterface_ianainterfacetype"] = "Ethernet"
                interfaces.append(details)

    return interfaces


### Start Sun os sessions ###

def gather_sunos_info(log_file: str):
    """Gather and log information about SunOS systems."""

    def get_general_information():
        uname_output = run_command("uname -srovni")
        tokens = uname_output.split()
        return {
            'OS Name': tokens[0],
            'OS Version': tokens[1].split('.')[1],
            'Kernel Version': tokens[2],
            'Hostname': tokens[3].split('.')[0],
            'System ID': tokens[4],
            'Manufacturer': 'Oracle'
        }

    def get_cpu_information():
        number_of_cpus = int(run_command("psrinfo -p"))
        cpu_information = run_command("psrinfo -pv").split("\n")[0]
        number_of_virtual_cpus = int(run_command("psrinfo | wc -l"))
        number_of_cpu_cores = int(run_command(
            "kstat -m cpu_info | grep core_id | uniq | wc -l"))
        cpu_mode = "64-bit" if "64-bit" in run_command(
            "isainfo -kv") else "32-bit"

        return {
            'Number of CPUs': number_of_cpus,
            'CPU Information': cpu_information,
            'Number of Virtual CPUs': number_of_virtual_cpus,
            'Number of CPU Cores': number_of_cpu_cores,
            'CPU Mode': cpu_mode
        }

    def get_memory_information():
        memory_size = int(run_command(
            "prtconf | grep 'Memory size' | awk '{print $3}'"))
        swap_memory_size = int(run_command(
            "swap -s | awk '{print $2}'").replace('k', ''))

        return {
            'Memory Size (MB)': memory_size,
            'Swap Memory Size (KB)': swap_memory_size
        }

    def get_network_information():
        ip_address = run_command(
            "ifconfig -a | grep inet | awk '{print $2}' | grep -v '127.0.0.1' | head -1")

        return {
            'IP Address': ip_address
        }

    def check_virtualization():
        virt_status_command = (
            "virtinfo -a 2>/dev/null | grep -c 'Domain role: logical'"
        )
        virt_status = run_command(virt_status_command)
        zone_name = run_command("zonename")

        if (int(virt_status) > 0 or
            zone_name != "global" or
                os.path.exists("/usr/bin/xenstore-read")):
            return "True"

        return "False"

    if run_command("uname -s") != "SunOS":
        print("Error: This script is intended for SunOS systems only.")
        return

    general_data = get_general_information()
    cpu_data = get_cpu_information()
    memory_data = get_memory_information()
    network_data = get_network_information()
    is_virtual = check_virtualization()

    collected_data = {
        **general_data,
        **cpu_data,
        **memory_data,
        **network_data,
        'Is Virtual': is_virtual,
        'Timezone': datetime.datetime.now().astimezone().tzname()
    }

    with open(log_file, 'a', encoding="utf-8") as file:
        file.write("\n\n Gathering SunOS information \n")
        file.write(f"Scan time: {datetime.datetime.now().isoformat()}\n")
        for key, value in collected_data.items():
            file.write(f"{key}: {value}\n")


def get_sunos_disks(ciname: str) -> list:
    """
    Retrieve SunOS disk information.
    """
    output = run_command("df -k | sort")
    lines = output.split("\n")[1:]
    filesystems = []

    for line in lines:
        parts = line.split()
        if parts[2] != "swap":
            parts[4] = parts[4].replace('%', '')
            filesystems.append({
                "classification": "ci.filesystem",
                "relation": "contains",
                "cinum": f"{ciname}:{parts[0]}",
                "ciname": f"{ciname}:{parts[5]}",
                "filesystem_type": parts[2],
                "filesystem_capacity": parts[3],
                "filesystem_availablespace": parts[4],
                "filesystem_mountpoint": parts[5]
            })
    return filesystems


def get_sunos_network_info():
    """
    Returns network interface details for a SunOS system.

    :return: dict with a list of network interface details
    """
    output = subprocess.getoutput('ifconfig -a')
    interfaces = []
    for line in output.splitlines():
        details = {}
        if line.startswith('lo'):
            continue
        if line.startswith('inet'):
            fields = line.split()
            address = fields[1]
            details["networkinterface_ipaddress"] = address
            interfaces.append(details)
    return {"interfaces": interfaces}

#### End Sun OS sessions ####


### Start AIX sessions ###
def get_aix_dependent_info():
    """Fetch AIX dependent system information."""

    # Fetch basic data
    data = {
        'scantime': fetch_scantime(),
        'hostname': fetch_hostname(),
        'computersystem_fqdn': fetch_fqdn(),
        'computersystem_virtual': fetch_virtualization(),
        'operatingsystem_osversion': fetch_os_version(),
        'OSLEVEL': fetch_os_level(),
        'computersystem_swapmemsize': fetch_swap_memory(),
        'prtconf_data': fetch_prtconf_data()
    }

    # Process the OS level data
    oslevel_parts = data['OSLEVEL'].split('-')
    data['operatingsystem_servicepack'] = (
        f"TL {oslevel_parts[1]} SP {oslevel_parts[2]}"
    )
    data['operatingsystem_kernelversion'] = data['OSLEVEL']

    # Fetch system and CPU information
    (data['computersystem_model'],
     data['computersystem_serialnumber'],
     data['computersystem_memorysize']) = fetch_computer_system_info(data['prtconf_data'])

    (data['computersystem_numcpus'],
     data['computersystem_cpucoresenabled'],
     data['computersystem_numvirtualcpus'],
     data['computersystem_cpumode'],
     data['computersystem_cputype']) = fetch_cpu_info(data['prtconf_data'])

    data['operatingsystem_osmode'] = fetch_os_mode(data['prtconf_data'])

    # Omitting 'prtconf_data' and 'OSLEVEL' from the return as they are intermediate variables
    return {key: value for key, value in data.items() if key not in ['prtconf_data', 'OSLEVEL']}


def get_aix_disks(ciname: str) -> list:
    """
    Retrieve AIX disk information.
    """
    output = run_command("df -mP | sort")
    lines = output.split("\n")[1:]
    filesystems = []

    for line in lines:
        parts = line.split()
        if "\\proc" not in line:
            filesystems.append({
                "classification": "ci.filesystem",
                "relation": "contains",
                "cinum": f"{ciname}:{parts[0]}",
                "ciname": f"{ciname}:{parts[5]}",
                "filesystem_type": "",
                "filesystem_capacity": parts[1],
                "filesystem_availablespace": parts[3],
                "filesystem_mountpoint": parts[5]
            })
    return filesystems


def get_aix_network_info():
    """
    Returns network interface details for an AIX system.

    :return: dict with a list of network interface details
    """
    output = subprocess.getoutput('ifconfig -a')
    interfaces = []
    for line in output.splitlines():
        details = {}
        if line.startswith('en'):
            fields = line.split()
            details["networkinterface_interfacename"] = fields[0].split(':')[0]
            details["networkinterface_adminstate"] = fields[-1].split('<')[
                1].split(',')[0]
        elif 'inet' in line:
            fields = line.split()
            address = fields[1]
            netmask = fields[3].replace('netmask', '').strip()
            details["networkinterface_ipaddress"] = address
            details["networkinterface_netmask"] = netmask
            interfaces.append(details)
    return {"interfaces": interfaces}

### End AIX sessions ###


def print_network_info():
    """
    Returns network interface details based on the detected operating system.

    :return: dict with a list of network interface details
    """
    uname = subprocess.getoutput('uname')
    hostname = get_hostname()

    if uname == "Linux":
        return get_linux_network_info(hostname)
    if uname == "AIX":
        return get_aix_network_info()
    if uname == "SunOS":
        return get_sunos_network_info()
    return {}  # Return an empty dictionary for any other/unexpected OS


def read_classifications(classification_file):
    """Read classifications from a CSV file."""
    with open(classification_file, 'r', encoding='utf-8') as file:
        next(file)  # Skip the header
        return {line.split(',')[0]: line.split(',')[1].strip()
                for line in file.readlines() if len(line.split(',')) > 1}


def process_line(line, classifications, ciname):
    """Process a line from the sss_file and return a subsystem dictionary."""
    # Database classifications
    db_classification = {
        'DB2': 'CI.DB2DATABASE',
        'MSL': 'CI.SQLSERVERDATABASE',
        'ORA': 'CI.ORACLEDATABASE',
        'MYL': 'CI.MYSQLSERVERDATABASE',
        'IFX': 'CI.INFORMIXDATABASE',
        'HAN': 'CI.SAPHANADATABASE',
        'SYB': 'CI.SYBASEDATABASE'
    }

    line = line.strip().replace("\r", "")
    parts = line.split(";")
    params = {part.split("=")[0]: part.split("=")[1]
              for part in parts if '=' in part}

    instance = params.get("SUBSYSTEM_INSTANCE", "")
    type_ = params.get("SUBSYSTEM_TYPE", "")
    version = params.get("MW_VERSION", "")
    edition = params.get("MW_EDITION", "")
    fixpack = params.get("FIXPACK", "")
    instpath = params.get("INSTANCE_PATH", "")
    dbname = params.get("DB_NAME", "")
    port = params.get("INSTANCE_PORT", "")
    classification = classifications.get(type_, "")

    subsystem = {
        "classification": classification,
        "inverse_relation": "runson",
        "cinum": f"{ciname}:{type_}:{instance}",
        "ciname": f"{ciname}:{instance}",
        "appserver_productname": edition,
        "appserver_productversion": version,
        "appserver_servicepack": fixpack,
        "appserver_vendorname": "",
        "type": type_,
        "installpath": instpath,
        "port": port
    }

    if type_ in db_classification.keys():
        subsystem["databases"] = [{
            "classification": db_classification[type_],
            "relation": "contains",
            "cinum": f"{ciname}:{type_}:{instance}:{dbname}",
            "ciname": f"{ciname}:{instance}:{dbname}",
            "database_name": dbname
        }]

    return subsystem


def parse_subsystem_information_for_json(sss_file_path, ciname, classification_file_path):
    """
    Parse subsystem information and return it.
    """
    subsystems = []
    classifications = read_classifications(classification_file_path)
    with open(sss_file_path, 'r', encoding='utf-8') as sss_file:
        sss_lines = sss_file.readlines()
    for sss_line in sss_lines:
        if "SUBSYSTEM_TYPE=OSL" not in sss_line and "SUBSYSTEM_INSTANCE=NO" not in sss_line:
            subsystems.append(process_line(sss_line, classifications, ciname))
    return {"subsystems": subsystems}


def process_ismbr_keys(computer_data):
    """Process the ismbr_cep1_1 and ismbr_cep1_2 keys based on computer data.

    Args:
        computer_data (dict): The 'computersystem' data.

    Returns:
        tuple: (ismbr_cep1_1, ismbr_cep1_2)
    """
    if computer_data["classification"] == "ci.windowscomputersystem":
        ismbr_cep1_1 = "OS / BUILT-IN"
        ismbr_cep1_2 = "SEE OS VERSION"
    else:
        ismbr_cep1_1 = "SUDO"
        sudo_version = None
        for subsystem in computer_data["subsystems"]:
            if (subsystem["appserver_productname"] == "sudo" or
               subsystem["appserver_productname"].endswith(".sudo")):
                sudo_version = subsystem["appserver_productversion"]
                break
        ismbr_cep1_2 = sudo_version if sudo_version else "Not found"

    return ismbr_cep1_1, ismbr_cep1_2


def collect_all_data(sss_file_path, ciname, log_file_path, classification_file_path):
    """
    Collects and organizes all the required data.

    Args:
    - sss_file_path (str): Path to the SSS file.
    - ciname (str): Hostname.
    - log_file_path (str): Path to the log file.
    - classification_file_path (str): Path to the classification file.

    Returns:
    dict: A dictionary containing all the collected data.
    """

    linux_info = collect_linux_info()
    linux_info.update(get_linux_dependent_info(log_file_path))

    computer_info = get_computer_system_info()
    architecture_info = get_architecture_independent_info()

    subsystems_info = parse_subsystem_information_for_json(
        sss_file_path, ciname, classification_file_path)

    network_info = print_network_info()
    disk_info = get_disks_info(ciname, os.uname().sysname)

    ciname = linux_info["hostname"].strip()

    cpu_info = get_cpu_info()
    system_info = get_system_info()

    prtconf_data = fetch_prtconf_data()
    cpu_data = fetch_cpu_info(prtconf_data)

    ismbr_cep1_1, ismbr_cep1_2 = process_ismbr_keys({
        "classification": linux_info["csclassification"],
        "subsystems": [subsystems_info["subsystems"]] if isinstance(subsystems_info["subsystems"], dict) else subsystems_info["subsystems"]
    })

    all_data = {
        "computersystem": {
            "classification": linux_info["csclassification"],
            "hostname": ciname,
            "cinum": ciname,
            "ciname": ciname,
            "computersystem_name": ciname,
            "computersystem_fqdn": linux_info.get("computersystem_fqdn", ""),
            "computersystem_virtual": architecture_info["computersystem_virtual"],
            "computersystem_numvirtualcpus": cpu_data[2],
            "computersystem_cpumode": architecture_info.get("computersystem_cpumode", ""),
            "computersystem_cputype": cpu_info["computersystem_cputype"],
            "computersystem_cpucoresenabled": cpu_info["computersystem_cpucoresenabled"],
            "computersystem_numcpus": cpu_info["computersystem_numcpus"],
            "computersystem_manufacturer": system_info["computersystem_manufacturer"],
            "computersystem_serialnumber": system_info["computersystem_serialnumber"],
            "computersystem_model": system_info["computersystem_model"],
            "computersystem_memorysize": architecture_info["computersystem_memorysize"],
            "computersystem_swapmemsize": architecture_info["computersystem_swapmemsize"],
            "computersystem_timezone": computer_info["computersystem_timezone"],
            "computersystem_dns": linux_info.get("computersystem_dns", ""),
            "modelobject_contextip": linux_info.get("modelobject_contextip", ""),
            "operating_system": {
                "classification": linux_info["osclassification"],
                "inverse_relation": "runson",
                "cinum": f"{ciname}:OS",
                "ciname": f"{ciname}:OS",
                "operatingsystem_osname": linux_info.get("operatingsystem_osname", ""),
                "operatingsystem_osversion": linux_info.get("operatingsystem_osversion", ""),
                "operatingsystem_servicepack": linux_info.get("operatingsystem_servicepack", ""),
                "operatingsystem_osmode": architecture_info["operatingsystem_osmode"],
                "operatingsystem_kernelversion": architecture_info["operatingsystem_kernelversion"],
                "ismbr_cep1_1": ismbr_cep1_1,
                "ismbr_cep1_2": ismbr_cep1_2,
            },
            "interfaces": [network_info] if isinstance(network_info, dict) else network_info,
            "filesystems": [disk_info] if isinstance(disk_info, dict) else disk_info,
            "subsystems": [subsystems_info["subsystems"]] if isinstance(subsystems_info["subsystems"], dict) else subsystems_info["subsystems"]
        },
        "pluspcustomer": "",
        "change": "",
        "scan_time": datetime.datetime.now().isoformat(),
        "jsonversion": "1"
    }

    # If OS is AIX, collect AIX dependent information and add to all_data
    if os.uname().sysname == "AIX":
        aix_info = get_aix_dependent_info()
        all_data["aix_dependent_info"] = aix_info

    return all_data


def validate_args():
    """
    Validate args
    """
    if len(sys.argv) < 3:
        print(
            "Required arguments missing. Usage: script.py sss_file_path output_file_path [classification_file_path]")
        sys.exit(1)
    return sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None


def main():
    """
    Main function to orchestrate the data collection and output generation.
    """
    # Validate and extract arguments
    sss_file_path, output_file_path, classification_file_path = validate_args()

    # Input argument handling
    sss_file_path = sys.argv[1] if len(sys.argv) > 1 else None
    output_file_path = sys.argv[2] if len(sys.argv) > 2 else None
    classification_file_path = sys.argv[3] if len(sys.argv) > 3 else None
    log_file_path = os.path.join(os.path.dirname(
        output_file_path), 'computersystem.log') if output_file_path else None
    ciname = socket.gethostname()

    # Get the system name for logging purposes
    uname = os.uname().sysname

    # Error handling for missing command line arguments or file issues
    if not sss_file_path or not output_file_path:
        print("Required arguments missing.")
        sys.exit(1)

    # Gather all data
    all_data = collect_all_data(
        sss_file_path, ciname, log_file_path, classification_file_path)

    # Write to output file
    with open(output_file_path, 'w', encoding='utf-8') as file:
        json.dump(all_data, file, indent=4)

    # Logging
    with open(log_file_path, 'a', encoding='utf-8') as log:
        log.write(f"Disk information for {uname}: \n")
        log.write(json.dumps(
            all_data["computersystem"]["filesystems"], indent=4))

    # Logging subsystems results
    with open(log_file_path, 'a', encoding='utf-8') as log_file:
        log_file.write("Print subsystems results \n")
        with open(sss_file_path, 'r', encoding='utf-8') as sss_file:
            for sss_line in sss_file:
                if "SUBSYSTEM_INSTANCE=NO" not in sss_line:
                    log_file.write(f"Command: {sss_line}\n\n")


if __name__ == "__main__":
    main()
