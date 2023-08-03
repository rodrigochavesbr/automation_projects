#!/usr/bin/env python

# -*- coding: utf-8 -*-

# @author Rodrigo Chaves <rschaves@kyndryl.com>
# @copyright (c) Kyndryl Inc. 2021. All Rights Reserved.
# @license Kyndryl Intellectual Property


""" send2now.py - Module for sending data to ServiceNow.
"""


#   Filename:send2now.py
#   Description: This script sends data to ServiceNow
#              It includes functions for parsing JSON data, mapping ICD classes,
#               to ServiceNow classes, and sending the data to ServiceNow.
#              This is not a module, but a script (see usage instructions)
#       Input: Parameters: clinet (prefix), hostname, ip, base_dir (with config folder)
#      Output: None
#       Usage: send2now.py
#            --client '{{ customer }}'
#           --file '{{ local_path }}/{{ hostname }}.{{ ["tgz", "zip"][ostype |
#   default(os_type) == "windows" and (tgz_file is not defined or tgz_file)] }}'
#           --ip '{{ ansible_host }}'
#           --url '{{ snow_credentials.url }}/api/ibmba/ibm_cmdb/createupdate_ci'
#           --username '{{ snow_credentials.credential }}'
#            --password '{{ snow_credentials.secret }}'
#     Pre-req: Config folder with CSVs and mapping files under local_path provided.
#      Author: Rodrigo Chaves <rschaves@kyndryl.com>
#    Releases: 1.0 2016/08/27 Initial Release
################################################################################

import argparse
import os
import json
import re
import sys
from collections import namedtuple
import tempfile
import tarfile
import zipfile
import requests
import yaml


# Mapping of incoming ICD classes to ServiceNow classes
osnow = {
    "ci.linuxcomputersystem":    'cmdb_ci_linux_server',
    "ci.aixcomputersystem":      'cmdb_ci_aix_server',
    "ci.sunsparccomputersystem": 'cmdb_ci_solaris_server',
    "ci.hpuxcomputersystem":     'cmdb_ci_hpux_server',
    "ci.windowscomputersystem":  'cmdb_ci_win_server'
}


AppInfo = namedtuple("AppInfo", ["nowclass", "manufacturer"])

global_app_map_default = {
    "apa": AppInfo("cmdb_ci_apache_web_server", "Apache Software Foundation"),
    "aaa": AppInfo("cmdb_ci_appl", "Open Source"),
    "afs": AppInfo("cmdb_ci_appl", "Open Source"),
    "axg": AppInfo("cmdb_ci_appl", "Axway Software"),
    "bes": AppInfo("cmdb_ci_appl", "BlackBerry Limited"),
    "bpm": AppInfo("cmdb_ci_app_server", "IBM"),
    "ccm": AppInfo("cmdb_ci_appl", "Microsoft Corporation"),
    "cft": AppInfo("cmdb_ci_appl", "Axway Software"),
    "dir": AppInfo("cmdb_ci_appl", "IBM"),
    "ina": AppInfo("cmdb_ci_appl", "IBM"),
    "isa": AppInfo("cmdb_ci_appl", "Microsoft Corporation"),
    "it6": AppInfo("cmdb_ci_appl", "IBM"),
    "mal": AppInfo("cmdb_ci_appl", "F-Secure Corporation"),
    "nco": AppInfo("cmdb_ci_appl", "IBM"),
    "noc": AppInfo("cmdb_ci_appl", "NetApp, Inc."),
    "nsm": AppInfo("cmdb_ci_appl", "NetApp, Inc."),
    "oem": AppInfo("cmdb_ci_appl", "Oracle Corporation"),
    "sbe": AppInfo("cmdb_ci_appl", "Broadcom Inc."),
    "sbl": AppInfo("cmdb_ci_app_server", "Oracle Corporation"),
    "sck": AppInfo("cmdb_ci_appl", "Open Source"),
    "smm": AppInfo("cmdb_ci_appl", "IBM"),
    "tdm": AppInfo("cmdb_ci_appl", "IBM"),
    "tem": AppInfo("cmdb_ci_appl", "HCL Technologies Limited"),
    "tim": AppInfo("cmdb_ci_appl", "IBM"),
    "tip": AppInfo("cmdb_ci_appl", "IBM"),
    "tpc": AppInfo("cmdb_ci_appl", "IBM"),
    "tpm": AppInfo("cmdb_ci_appl", "IBM"),
    "tsm": AppInfo("cmdb_ci_appl", "IBM"),
    "tws": AppInfo("cmdb_ci_appl", "HCL Technologies Limited"),
    "wpr": AppInfo("cmdb_ci_appl", "Open Source"),
    "wts": AppInfo("cmdb_ci_appl", "Microsoft Corporation"),
    "xfb": AppInfo("cmdb_ci_appl", "Axway Software"),
    "dom": AppInfo("cmdb_ci_appl_domino", "HCL Technologies Limited"),
    "jbs": AppInfo("cmdb_ci_app_server_jboss", "IBM"),
    "oas": AppInfo("cmdb_ci_app_server_ora_ias", "Oracle Corporation"),
    "tom": AppInfo("cmdb_ci_app_server_tomcat", "Open Source"),
    "bea": AppInfo("cmdb_ci_app_server_weblogic", "Oracle Corporation"),
    "was": AppInfo("cmdb_ci_app_server_websphere", "IBM"),
    "wlp": AppInfo("cmdb_ci_app_server_websphere", "IBM"),
    "adi": AppInfo("cmdb_ci_appl_active_directory", "Microsoft Corporation"),
    "ctx": AppInfo("cmdb_ci_appl_citrix_xenapp", "Citrix Systems, Inc."),
    "csf": AppInfo("cmdb_ci_appl_citrix_xenapp", "Citrix Systems, Inc."),
    "wmb": AppInfo("cmdb_ci_appl_ibm_wmb", "IBM"),
    "mqm": AppInfo("cmdb_ci_appl_ibm_wmq", "IBM"),
    "sap": AppInfo("cmdb_ci_appl_sap", "SAP SE"),
    "shp": AppInfo("cmdb_ci_appl_sharepoint", "Microsoft Corporation"),
    "wps": AppInfo("cmdb_ci_appl_websphere_portal", "HCL Technologies Limited"),
    "db2": AppInfo("cmdb_ci_db_db2_instance", "IBM"),
    "ifx": AppInfo("cmdb_ci_db_instance", "IBM"),
    "mxd": AppInfo("cmdb_ci_db_instance", "SAP SE"),
    "han": AppInfo("cmdb_ci_db_instance", "SAP SE"),
    "msl": AppInfo("cmdb_ci_db_mssql_instance", "Microsoft Corporation"),
    "ors": AppInfo("cmdb_ci_db_mssql_reporting", "Microsoft Corporation"),
    "myl": AppInfo("cmdb_ci_db_mysql_instance", "Oracle Corporation"),
    "ora": AppInfo("cmdb_ci_db_ora_instance", "Oracle Corporation"),
    "pgs": AppInfo("cmdb_ci_db_postgresql_instance", "Open Source"),
    "syb": AppInfo("cmdb_ci_db_syb_instance", "SAP SE"),
    "exc": AppInfo("cmdb_ci_exchange_service_component", "Microsoft Corporation"),
    "kvm": AppInfo("cmdb_ci_kvm", "Open Source"),
    "iis": AppInfo("cmdb_ci_microsoft_iis_web_server", "Microsoft Corporation"),
    "ngx": AppInfo("cmdb_ci_nginx_web_server", "Open Source"),
    "vce": AppInfo("cmdb_ci_vcenter", "VMware, Inc."),
    "smb": AppInfo("cmdb_ci_appl", "Open Source"),
    "ssh": AppInfo("cmdb_ci_appl", "Open Source"),
    "sdo": AppInfo("cmdb_ci_appl", "Open Source")
}

# Move the 'apptypes' dictionary outside the function and make it a global constant
apptypes = {
    'it6': 'computersystem_monitoring_agent',
    'tem': 'computersystem_inventory_agent',
    'sdo': {
        'ismbr_cep1_1': 'SUDO',
        'ismbr_cep1_2': ''
    }
}


def parse_arguments():
    """ Parse command-line arguments and return the parsed arguments.

    Parses the command-line arguments, including client, file, IP, change,
    URL, username, and password, and returns the parsed arguments.
    """

    parser = argparse.ArgumentParser(
        description='Parse json and send to ServiceNow')
    parser.add_argument('-c', '--client', dest='client', required=True,
                        help='GSMA Client code with three letters')
    parser.add_argument('-f', '--file', dest='file', required=True,
                        help='Full path to file to be parsed and posted to ServiceNow')
    parser.add_argument('-i', '--ip', dest='ip',
                        help='IP used to connected to this server, in ansible, usually ansible_host')
    parser.add_argument('--change', dest='change',
                        help='Identification of change responsible to activate this device')
    parser.add_argument('-u', '--url', dest='url',
                        required=True, help='ServiceNow URL')
    parser.add_argument('--username', dest='username', default=os.getenv('snow_user'),
                        required=False, help='ServiceNow username')
    parser.add_argument('-p', '--password', dest='password', default=os.getenv('snow_password'),
                        required=False, help='ServiceNow password')

    parsed_args = parser.parse_args()

    # If username or password are not provided via command line, attempt to get from environment
    if not parsed_args.username:
        if os.getenv('snow_user'):
            parsed_args.username = os.getenv('snow_user')
        else:
            raise argparse.ArgumentError(
                None, "ServiceNow username must be provided via --username or snow_user environment variable")

    if not parsed_args.password:
        if os.getenv('snow_password'):
            parsed_args.password = os.getenv('snow_password')
        else:
            raise argparse.ArgumentError(
                None, "ServiceNow password must be provided via --password or snow_password environment variable")

    return parsed_args


def create_temporary_directory():
    """ Creates a temporary directory and returns a context manager for it."""
    try:
        return tempfile.TemporaryDirectory()
    except OSError as error:
        print(f'Could not create temporary directory: {error}.')
        sys.exit(1)


def uncompress(file=None, tempdir=None):
    """ Uncompresses the given file to the specified temporary directory.
    Returns the path of the uncompressed JSON file.
    """

    host, extension = os.path.basename(file).split('.')
    file_data = 'tgz'
    if extension == file_data:
        try:
            tar = tarfile.open(file)
        except (FileNotFoundError, tarfile.TarError) as error:
            print(f"ERROR uncompressing {file}: {error}")
            sys.exit(1)
        else:
            with tar:
                tar.extract(f'{host}.json', path=tempdir)
    else:
        try:
            zip_file = zipfile.ZipFile(file)
        except (FileNotFoundError, zipfile.BadZipFile) as error:
            print(f"ERROR uncompressing {file}: {error}")
            sys.exit(1)
        else:
            with zip_file:
                zip_file.extract(f'{host}.json', path=tempdir)

    print(f"{file} successfully uncompressed.")
    return os.path.join(tempdir, f'{host}.json')


def load_yaml(file=None):
    """ Loads and parses a YAML file.
    Args:
        file (str): The path to the YAML file.
    Returns:
        dict: The parsed YAML data.
    """
    # Get script path
    file_fullpath = os.path.join(
        os.path.dirname(os.path.realpath(__file__)), file)

    try:
        yaml_file = open(file_fullpath, 'r', encoding='utf-8')
    except OSError as error:
        print(f"ERROR opening {file_fullpath}: {error}")
        sys.exit(1)
    else:
        with yaml_file:
            try:
                data = yaml.safe_load(yaml_file)
            except yaml.YAMLError as error:
                print(f"ERROR parsing {file_fullpath}: {error}")
                sys.exit(1)

    if data is None:
        print(f"ERROR loading {file_fullpath}: Empty file.")
        sys.exit(1)

    print(f"{file_fullpath} successfully loaded.")
    return data


def append_status(status=None, text=None):
    """ Appends the status to the text.

    Args:
        status (str): The status value.
        text (str): The text to be appended.

    Returns:
        str: The updated text.
    """
    sucess_status = 'OK'  # Define OK as a named constant

    new_text = text if status == sucess_status else f"{status}, {text}"
    return new_text


def parse(options):
    """ Parse the JSON data and create a new dictionary with transformed data.

    Args:
        options (dict): Options dictionary containing all the necessary parameters.

    Returns:
        dict: The transformed data in a new dictionary format.
    """
    u_ibm_last_discovered_status = 'OK'

    client = options['customer_options'].get('client', None)
    ip_data = options['customer_options'].get('ip', None)
    change = options['customer_options'].get('change', None)

    if client is not None:
        client = client.upper()

    with open(options['json_file'], encoding='utf-8') as file:
        data = json.load(file)

    print(f"Original Json:\n{json.dumps(data, indent=2)}\n")

    scantime = re.sub(r"^(.{10}).(.{8}).*", r"\1 \2", data["scan_time"])

    manufacturer, u_ibm_last_discovered_status = process_manufacturer(
        data, options['manufacturer_map'], u_ibm_last_discovered_status)
    model, u_ibm_last_discovered_status = process_model(
        data, manufacturer, options['hw_map'], u_ibm_last_discovered_status)

    scan_info = {"scantime": scantime, "change": change, "ip_data": ip_data}
    system_info = {"manufacturer": manufacturer, "model": model,
                   "u_ibm_last_discovered_status": u_ibm_last_discovered_status}

    new = create_new_dict(data, client, scan_info,
                          system_info, options['app_map'])

    print("Json to be sent to ServiceNow:")
    print(json.dumps(new, indent=2))
    print()

    return new


def process_manufacturer(data, manufacturer_map, u_ibm_last_discovered_status):
    """ Process the manufacturer data and update the status if not mapped.

    Args:
        data (dict): The JSON data.
        manufacturer_map (dict): Mapping of manufacturer details.
        u_ibm_last_discovered_status (str): The current status.

    Returns:
        tuple: The processed manufacturer and updated status.
    """
    manufacturer = data["computersystem"]["computersystem_manufacturer"].strip()
    if manufacturer.lower() in manufacturer_map:
        manufacturer = manufacturer_map[manufacturer.lower()]
    else:
        u_ibm_last_discovered_status = append_status(status=u_ibm_last_discovered_status,
                                                     text=f"Manufacturer '{manufacturer}' is not mapped")
    return manufacturer, u_ibm_last_discovered_status


def process_model(data, manufacturer, hw_map, u_ibm_last_discovered_status):
    """ Process the model data and update the status if not mapped.

    Args:
        data (dict): The JSON data.
        manufacturer (str): The processed manufacturer.
        hw_map (dict): Mapping of hardware details.
        u_ibm_last_discovered_status (str): The current status.

    Returns:
        tuple: The processed model and updated status.
    """
    model = ' '.join(data["computersystem"]["computersystem_model"].split())
    if manufacturer.lower() in hw_map and model.lower() in hw_map[manufacturer.lower()]:
        model = hw_map[manufacturer.lower()][model.lower()]
    else:
        u_ibm_last_discovered_status = append_status(
            status=u_ibm_last_discovered_status,
            text=f"Manufacturer '{manufacturer}' or model '{model}' are not mapped")
    return model, u_ibm_last_discovered_status


def create_new_dict(data, client, scan_info, system_info, app_map):
    """ Create a new dictionary with transformed data.

    Args:
        data (dict): The JSON data.
        client (str): The client information.
        scan_info (dict): Dictionary containing 'scantime', 'change', and 'ip_data'.
        system_info (dict): Dictionary containing 'manufacturer', 'model', and 'u_ibm_last_discovered_status'.
        app_map (dict): The application map.

    Returns:
        dict: The transformed data in a new dictionary format.
    """
    computersystem_fqdn = 'computersystem_fqdn'
    computersystem_domain = 'computersystem_domain'
    cmdb_ci_win_server = 'cmdb_ci_win_server'

    new = {
        "discovery_source": "NEXT Discovery",
        "scan_time": scan_info["scantime"],
        "parent_class": 'cmdb_ci_server',
        "customer": client,
        "classification": osnow[data["computersystem"]["classification"]],
        "hostname": data["computersystem"]["hostname"].lower(),
        "cinum": data["computersystem"]["cinum"],
        "ciname": data["computersystem"]["ciname"].lower(),
        "computersystem_name": data["computersystem"]["computersystem_name"].lower(),
        "computersystem_fqdn": (
            data["computersystem"]
            .get(computersystem_fqdn, data["computersystem"]["computersystem_name"])
            .lower()
        ),
        "computersystem_virtual": data["computersystem"]["computersystem_virtual"],
        "computersystem_cputype": data["computersystem"]["computersystem_cputype"].strip(),
        "computersystem_cpucoresenabled": data["computersystem"]["computersystem_cpucoresenabled"],
        "computersystem_numcpus": data["computersystem"]["computersystem_numcpus"],
        "computersystem_memorysize": data["computersystem"]["computersystem_memorysize"],
        "computersystem_swapmensize": data["computersystem"]["computersystem_swapmensize"],
        "computersystem_manufacturer": system_info["manufacturer"],
        "computersystem_serialnumber": data["computersystem"]["computersystem_serialnumber"].strip(),
        "computersystem_model": system_info["model"],
        "computersystem_timezone": data["computersystem"]["computersystem_timezone"],
        "operatingsystem_osname": (
            data["computersystem"]
            ["operating_system"]
            ["operatingsystem_osname"]
            .strip()
        ),
        "operatingsystem_osversion": (
            data["computersystem"]
            ["operating_system"]
            ["operatingsystem_osversion"]
            .strip()
        ),
        "operatingsystem_servicepack": (
            data["computersystem"]
            ["operating_system"]
            ["operatingsystem_servicepack"]
            .strip()
        ),
        "operatingsystem_osmode": (
            data["computersystem"]
            ["operating_system"]
            ["operatingsystem_osmode"]
            .strip()
        ),
        "operatingsystem_kernelversion": (
            data["computersystem"]
            ["operating_system"]
            ["operatingsystem_kernelversion"]
            .strip()
        ),
        "computersystem_monitoring_agent": "N",
        "computersystem_inventory_agent": "N",
        "u_ibm_last_discovered_status": system_info["u_ibm_last_discovered_status"],
        "interfaces": [],
        "filesystems": []
    }

    if computersystem_domain in data["computersystem"] and data["computersystem"][computersystem_domain]:
        domain = data["computersystem"][computersystem_domain]
        if 'workgroup' in domain.lower():
            new["os_domain"] = ''
        else:
            new["os_domain"] = domain

    if scan_info["change"]:
        new["change"] = scan_info["change"]

    if scan_info["ip_data"]:
        new["ip_address"] = scan_info["ip_data"]

    if new["classification"] == cmdb_ci_win_server:
        new["ismbr_cep1_1"] = "OS / BUILT-IN"
        new["ismbr_cep1_2"] = "SEEOSVERSION"

    new["interfaces"] = process_network_interfaces(data, client, new)
    new["filesystems"] = process_filesystems(data, client, new)
    new["subsystems"] = process_subsystems(
        data, client, app_map, app_map["global_app_map_default"], scan_info["scantime"])

    return new


def process_network_interfaces(data, client, new):
    """ Process network interfaces data and create a list of transformed interfaces.

    Args:
        data (dict): The input data dictionary.
        client (str): The client information.
        new (dict): The new dictionary being constructed.

    Returns:
        list: The list of transformed network interfaces.
    """

    not_applicable = 'N/A'
    unspecified = 'UNSPEC'
    ethernet_address = 'ETHERNET'
    interfaces_key = 'interfaces'

    new_interfaces = []

    if interfaces_key in data["computersystem"]:
        for interface in data["computersystem"][interfaces_key]:
            ip_address = interface["networkinterface_ipaddress"]
            if (
                ip_address
                and ip_address != not_applicable
                and ip_address != unspecified
                and ip_address != ethernet_address
            ):
                new_interfaces.append({
                    "discovery_source": "NEXT Discovery",
                    "classification": 'cmdb_ci_network_adapter',
                    "relation": 'contains',
                    "customer": client,
                    "name": interface["cinum"],
                    "ciname": new["ciname"],
                    "networkinterface_ipaddress": ip_address,
                    "networkinterface_netmask": interface["networkinterface_netmask"],
                    "networkinterface_interfacename": interface["networkinterface_interfacename"],
                    "networkinterface_adminstate": interface["networkinterface_adminstate"],
                    "networkinterface_ianainterfacetype": interface["networkinterface_ianainterfacetype"],
                    "networkinterface_physicaladdress": interface["networkinterface_physicaladdress"]
                })

    return new_interfaces


def process_filesystems(data, client, new):
    """ Process filesystems data and create a list of transformed filesystems.

    Args:
        data (dict): The input data dictionary.
        client (str): The client information.
        new (dict): The new dictionary being constructed.

    Returns:
        list: The list of transformed filesystems.
    """

    filesystems_key = 'filesystems'
    new_filesystems = []

    if filesystems_key in data["computersystem"]:
        for fs_data in data["computersystem"][filesystems_key]:
            new_filesystems.append({
                "discovery_source": "NEXT Discovery",
                "classification": 'cmdb_ci_file_system',
                "relation": 'contains',
                "name": re.sub(r"^[^:]*:", "", fs_data["cinum"]),
                "ciname": new["ciname"],
                "customer": client,
                "filesystem_type": fs_data["filesystem_type"].lower(),
                "filesystem_capacity": str(int(fs_data["filesystem_capacity"]) * 1024 * 1024),
                "filesystem_freespace": str(int(fs_data["filesystem_availablespace"]) * 1024 * 1024),
                "filesystem_mountpoint": fs_data["filesystem_mountpoint"]
            })

    return new_filesystems


def process_subsystems(data, client, app_map, app_map_default, scantime):
    """ Process subsystems data and create a dictionary of transformed subsystems.

    Args:
        data (dict): The input data dictionary.
        client (str): The client information.
        app_map (dict): Mapping of application details.
        app_map_default (dict): Default mapping of application details.
        scantime (str): The scan time information.

    Returns:
        dict: The dictionary of transformed subsystems.
    """
    new_subsystems = {}
    default_version = '0.0.0'

    def process_subsystem(subsystem):
        apptype = subsystem["type"].lower()
        key = f"{apptype}.{subsystem['appserver_productname'].lower()}"

        if apptype in apptypes:
            if isinstance(apptypes[apptype], str):
                new_subsystems[apptypes[apptype]] = "Y"
            else:
                new_subsystems.update(apptypes[apptype])

        if should_ignore_apptype(apptype, key):
            return

        nowclass, product_name, product_manufacturer, u_ibm_last_discovered_status = (
            get_subsystem_details(apptype, key, app_map,
                                  app_map_default, subsystem)
        )

        if nowclass is None or apptype in {'iis', 'shp', 'exc', 'ctx', 'was'}:
            return

        version = (
            'N/A'
            if subsystem["appserver_productversion"] == default_version
            else subsystem["appserver_productversion"]
        )

        short_description = f"{product_name} {version}"
        subsystem_data = {
            "nowclass": nowclass,
            "product_name": product_name,
            "version": version,
            "short_description": short_description,
            "scantime": scantime,
            "u_ibm_last_discovered_status": u_ibm_last_discovered_status,
            "client": client,
            "key_path": 'path',
            "key_port": 'port',
            # add product_manufacturer to your subsystem_data dictionary
            "product_manufacturer": product_manufacturer
        }

        add_subsystem_data(new_subsystems, nowclass, subsystem_data)

    subsystems_key = 'subsystems'

    if subsystems_key in data["computersystem"]:
        for subsystem in data["computersystem"][subsystems_key]:
            process_subsystem(subsystem)

    return new_subsystems


def add_subsystem_data(new_subsystems, nowclass, subsystem_data):
    """ Add subsystem data to the new_subsystems dictionary.

    Args:
        new_subsystems (dict): The dictionary of transformed subsystems.
        nowclass (str): The nowclass value.
        subsystem_data (dict): The subsystem data dictionary.
    """
    if nowclass not in new_subsystems:
        new_subsystems[nowclass] = [subsystem_data]
    else:
        new_subsystems[nowclass].append(subsystem_data)


def should_ignore_apptype(apptype, key):
    """ Check if the given application type and key should be ignored.

    Args:
        apptype (str): The application type.
        key (str): The key value.

    Returns:
        bool: True if the application type and key should be ignored,
        False otherwise.
    """

    ignored_types = {'cmc', 'dmn', 'fra', 'ilk', 'itm', 'oic', 'osl',
                     'rsa', 'scm', 'shs', 'ssk', 'ssl', 't4d', 'tm5', 'kvm', 'cfs', 'spt'}
    ignored_keywords = {'client', 'agent', 'fta'}

    if (
        apptype in ignored_types
        or (
            apptype in {'afs', 'ccm', 'dir', 'ina', 'it6',
                        'mal', 'sbe', 'smm', 'tem', 'tsm', 't4d'}
            and any(keyword in key for keyword in ignored_keywords)
        )
    ):
        return True
    return False


def get_subsystem_details(apptype, key, app_map, app_map_default, subsystem):
    """ Get the subsystem details based on the application type and key.

    Args:
        apptype (str): The application type.
        key (str): The key value.
        app_map (dict): Mapping of application details.
        app_map_default (dict): Default mapping of application details.
        subsystem (dict): The subsystem data.

    Returns:
        tuple: A tuple containing the nowclass, product_name, product_manufacturer,
        and u_ibm_last_discovered_status.
    """

    if key in app_map:
        nowclass = app_map[key]['nowclass']
        product_name = app_map[key]["product"]
        product_manufacturer = app_map[key]["manufacturer"]
        u_ibm_last_discovered_status = "OK"
    else:
        appinfo = app_map_default[apptype]
        nowclass = appinfo.nowclass
        product_name = subsystem["appserver_productname"]
        product_manufacturer = appinfo.manufacturer
        u_ibm_last_discovered_status = (
            f"Subsystem '{key}' is not mapped to a nice name. "
            "Need to add to appmapping file."
        )

    return nowclass, product_name, product_manufacturer, u_ibm_last_discovered_status


def create_subsystem_data(subsystem, data):
    """ Create a dictionary of subsystem data based on the provided information.

    Args:
        subsystem (dict): The subsystem data.
        data (dict): Additional data for creating the subsystem dictionary.

    Returns:
        dict: The dictionary containing the subsystem data.
    """

    subsystem_data = {
        "discovery_source": "NEXT Discovery",
        "ciname": subsystem["ciname"],
        "u_ibm_cmdb_ci": subsystem["ciname"],
        "name": subsystem["cinum"],
        "customer": data["client"],
        "company": data["client"],
        "appserver_productname": data["product_name"],
        "u_ibm_product_name": data["product_name"],
        "appserver_productversion": data["version"],
        "version": data["version"],
        "short_description": data["short_description"],
        "last_discovered": data["scantime"],
        "manufacturer": data["product_manufacturer"],
        "u_ibm_last_discovered_status": data["u_ibm_last_discovered_status"],
        "relationship": [
            {
                "inverse_relation": "Runs on::Runs",
                "name": subsystem["ciname"],
                "parent": subsystem["cinum"],
                "code": data["client"]
            }
        ]
    }

    if data["key_path"] in subsystem:
        subsystem_data["install_directory"] = subsystem[data["key_path"]]

    if data["key_port"] in subsystem:
        subsystem_data["tcp_port"] = subsystem[data["key_port"]]

    if re.search("^cmdb_ci_db.*_instance$", data["nowclass"]):
        _host, _apptype, instance = subsystem["cinum"].split(":")
        subsystem_data["u_ibm_instance_db_name"] = instance

    if data["nowclass"].startswith("cmdb_ci_appl_sap"):
        _host, sid = subsystem["ciname"].split(":")
        subsystem_data["sid"] = sid

    return subsystem_data


# Post payload to ServiceNow

def post(payload: dict = None, url: str = None, username: str = None, password: str = None) -> None:
    """ Sends data using the provided credentials and payload.
    :param payload: The data payload to be sent. [Specify the parameter type]
    :param url: The URL to which the data will be sent. [Specify the parameter type]
    :param username: The username for authentication. [Specify the parameter type]
    :param password: The password for authentication. [Specify the parameter type]
    """
    print(f"Posting to ServiceNow at {url} with user {username}")
    try:
        request_data = requests.post(
            url, json=payload, auth=(username, password), timeout=30)
    except requests.exceptions.RequestException as except_data:
        print(f"Error posting to ServiceNow: {except_data}")
    else:
        print(
            f"status_code {request_data.status_code}, content: {request_data.content}")


if __name__ == '__main__':
    # Parse arguments
    args = parse_arguments()

    # Load mappings, they must be on the same path as this script.
    app_map_data = load_yaml(file="application.map.yaml")
    manufacturer_map_data = load_yaml(file="manufacturer.map.yaml")
    hw_map_data = load_yaml(file="hw.map.yaml")

    # Create a temporary work directory to uncompress zip/tgz file
    # It is automatically removed at the end of the script

    with create_temporary_directory() as temp_dir_context:
        use_tempdir = temp_dir_context

        # Uncompress the file, it returns the JSON file's full path to be processed
        json_file_path = uncompress(file=args.file, tempdir=use_tempdir)

        # Work on the JSON to send to ServiceNow
        customer_options = {
            'client': args.client,
            'ip': args.ip,
            'change': args.change
        }

        # Combine app_map_data and global_app_map_default
        combined_app_map_data = {**app_map_data,
                                 'global_app_map_default': global_app_map_default}

        parse_options = {
            'json_file': json_file_path,
            'customer_options': customer_options,
            'app_map': combined_app_map_data,
            'manufacturer_map': manufacturer_map_data,
            'hw_map': hw_map_data,
        }

        # Work on the JSON to send to ServiceNow
        payload_data = parse(parse_options)

        # Send to ServiceNow
        post(payload=payload_data, url=args.url,
             username=args.username, password=args.password)

        # Unset the environment variables after using them
        os.environ.pop('snow_user', None)
        os.environ.pop('snow_password', None)
