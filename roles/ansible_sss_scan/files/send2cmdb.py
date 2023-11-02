#!/usr/bin/env python

# -*- coding: utf-8 -*-

# @author Rodrigo Chaves <rschavesbr@gmail.com>


""" send2cmdb.py - Module for sending data to Maximo.
"""


#   Filename:send2cmdb.py
#   Description: This script sends data to CMDB
#              It includes functions for parsing JSON data, mapping ICD classes,
#               to Maximo classes, and sending the data to Maximo.
#              This is not a module, but a script (see usage instructions)
#       Input: Parameters: clinet (prefix), hostname, ip, base_dir (with config folder)
#      Output: None
#       Usage: send2cmdb.py
#            --client '{{ customer }}'
#           --file '{{ local_path }}/{{ hostname }}.{{ ["tgz", "zip"][ostype |
#   default(os_type) == "windows" and (tgz_file is not defined or tgz_file)] }}'
#           --ip '{{ ansible_host }}'
#           --url '{{ snow_credentials.url }}/api/ibmba/ibm_cmdb/createupdate_ci'
#           --username '{{ snow_credentials.credential }}'
#            --password '{{ snow_credentials.secret }}'
#     Pre-req: Config folder with CSVs and mapping files under local_path provided.
#      Author: Rodrigo Chaves 
################################################################################

import argparse
import os
import json
import sys
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

# Move the 'apptypes' dictionary outside the function and make it a global constant
apptypes = {
    'it6': 'computersystem_monitoring_agent',
    'tem': 'computersystem_inventory_agent',
    'sdo': {
        'ismbr_cep1_1': 'SUDO',
        'ismbr_cep1_2': ''
    }
}

customers_maximo = {
    "adp": "ADP-00",
    "af1": "AF1-00",
    "anb": "ABI-00",
    "apg": "AP1-00",
    "ar9": "AR9-00",
    "asi": "ASI-00",
    "azz": "AZZ-01",
    "bag": "BAG-00",
    "bch": "BCH-00",
    "b7p": "B7P-00",
    "brm": "BRM-00",
    "brn": "BRK-00",
    "brp": "BRP-00",
    "bvs": "BVS-00",
    "bcg": "BC5-00",
    "car": "CAR-00",
    "ceb": "CEB-00",
    "cig": "CIG-00",
    "cmo": "CMO-00",
    "con": "CON-00",
    "cop": "COR-00",
    "cro": "CRO-00",
    "d1t": "DLT-00",
    "don": "DON-00",
    "dsp": "DSP-00",
    "elo": "ELO-00",
    "elc": "ELD-00",
    "ete": "ETE-00",
    "f1o": "F1O-00",
    "fle": "FLE-01",
    "fpk": "FPK-00",
    "fsh": "FSH-00",
    "fta": "FTA-00",
    "g2t": "G2T-00",
    "ger": "GER-00",
    "gna": "GER-01",
    "grr": "GRR-00",
    "gri": "GRI-00",
    "gur": "GER-02",
    "hmc": "HMC-00",
    "hm2": "HMC-00",
    "idk": "ITD-00",
    "iil": "ITD-03",
    "ime": "IME-00",
    "imx": "ITD-06",
    "inn": "ITD-10",
    "irc": "ITD-12",
    "isn": "ITD-14",
    "isp": "ITD-15",
    "isx": "ITD-16",
    "ivc": "ITD-17",
    "ilb": "ITD-05",
    "lai": "IGA-09",
    "lai4": "IGA-09",
    "las": "LAS-00",
    "ler": "LER-00",
    "lio": "LIO-00",
    "lir": "LIR-00",
    "mal": "MAN-00",
    "mci": "ITD-25",
    "mul": "MUL-00",
    "obt": "OBT-00",
    "onf": "ONF-00",
    "pda": "GPA-00",
    "peq": "PEQ-00",
    "per": "PER-00",
    "pvi": "PVI-00",
    "rdc": "RDC-00",
    "ric": "RIC-00",
    "rrc": "RRC-00",
    "rsa": "RSA-00",
    "rss": "ROS-00",
    "s1r": "SRB-00",
    "sdx": "SDX-00",
    "sgb": "SGB-00",
    "ss1": "SS1-00",
    "scp": "SCP-00",
    "spr": "SPC-00",
    "st3": "ST3-00",
    "tam": "TAM-01",
    "ter": "TSP-00",
    "tig": "TIG-00",
    "tkt": "TKT-00",
    "tpe": "TPE-00",
    "toy": "TOY-00",
    "u7p": "U7P-00",
    "uat": "IBM-16",
    "vnt": "CLO-00",
    "vvo": "VVO-00",
    "zts": "ZTS-00",
    "glx": "TVG-01",
}


def parse_arguments():
    """
    Parse command-line arguments.

    This function is designed to retrieve various server-related details
    from the command-line, such as IP, hostname, client identifier,
    change identifier, and file path. It also provides options for
    specifying the Maximo credentials and URL.

    Returns:
        argparse.Namespace: An object representing the parsed arguments.

    Arguments:
        -c, --client: GSMA Client code with three letters.
        -f, --file: Full path to the file to be processed.
        -i, --ip: IP used to connect to this server (usually ansible_host in Ansible).
        --change: Identification of change responsible to activate this device.
        -u, --url: Maximo URL.
        --username: Maximo username (defaults to environment variable 'post_user').
        -p, --password: Maximo password (defaults to environment variable 'post_password').
    """
    parser = argparse.ArgumentParser(
        description='Parse json and send to Maximo')

    parser.add_argument('-c', '--client', dest='client', required=True,
                        help='GSMA Client code with three letters')
    parser.add_argument('-f', '--file', dest='file', required=True,
                        help='Full path to the file to be processed.')
    parser.add_argument('-i', '--ip', dest='ip',
                        help='IP used to connect to this server (usually ansible_host in Ansible).')
    parser.add_argument('--change', dest='change',
                        help='Identification of change responsible to activate this device')
    parser.add_argument('-u', '--url', dest='url', required=True,
                        help='Maximo URL')
    parser.add_argument('--username', dest='username', default=os.getenv('post_user'),
                        help='Maximo username (defaults to environment variable post_user)')
    parser.add_argument('-p', '--password', dest='password', default=os.getenv('post_password'),
                        help='Maximo password (defaults to environment variable post_password)')
    parser.add_argument('--config_dir', required=True)

    return parser.parse_args()


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

    host, extension = os.path.splitext(os.path.basename(file))
    # Remove the leading dot from the extension
    extension = extension.lstrip('.')

    valid_tar_extensions = ['tgz', 'tar.gz']

    if extension in valid_tar_extensions:
        try:
            tar = tarfile.open(file)
        except (FileNotFoundError, tarfile.TarError) as error:
            raise ValueError(f"ERROR uncompressing {file}: {error}") from error

        with tar:
            tar.extract(f'{host}.json', path=tempdir)

    elif extension == 'zip':
        try:
            zip_file = zipfile.ZipFile(file)
        except (FileNotFoundError, zipfile.BadZipFile) as error:
            raise ValueError(f"ERROR uncompressing {file}: {error}") from error

        with zip_file:
            zip_file.extract(f'{host}.json', path=tempdir)

    else:
        raise ValueError(f"Unsupported file extension: {extension}")

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


def get_subsystem_details(key, app_map):
    """ Get the subsystem details based on the application type and key.

    Args:
        apptype (str): The application type.
        key (str): The key value.
        app_map (dict): Mapping of application details.
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
        # Set to 'N/A' for missing details
        nowclass = 'N/A'
        product_name = 'N/A'
        product_manufacturer = 'N/A'
        u_ibm_last_discovered_status = (
            f"Subsystem '{key}' is not mapped to a nice name. "
            "Need to add to appmapping file."
        )

    return nowclass, product_name, product_manufacturer, u_ibm_last_discovered_status


def load_cinum_map(client, config_dir):
    """Load cinum mapping from a CSV file.

    Args:
        client (str): The client name used to find the CSV file.

    Returns:
        dict: A dictionary with the cinum mapping.
    """
    cinummap = {}
    client = client.lower()  # Convert client to lowercase
    filename = os.path.join(config_dir, f"{client}.mapping.csv")
    if os.path.exists(filename):
        print(f"Loading mappings from {filename}")  # Success message
        with open(filename, 'r', encoding='ISO-8859-1') as map_file:
            for line in map_file:
                line = line.strip()
                # Check if line is not empty
                if line and not line.startswith('#'):
                    parts = line.split(',')
                    if len(parts) != 2:
                        print(
                            f"Warning: Unexpected format in line '{line}'. Skipping.")
                        continue
                    cinum, maxcinum = parts
                    cinum = cinum.lower()
                    cinummap[cinum] = maxcinum
    else:
        print(f"Warning: File not found: {filename}")

    return cinummap


def create_new_dict(original_data, scan_info, ip_data, pluspcustomer, client):
    """Transforms the original data to create a new dictionary.

    Args:
        original_data (dict): Original JSON data.
        scan_info (dict): Dictionary containing scan-related information.
        ip_data (str): IP-related data.
        pluspcustomer (str): Value to be set for pluspcustomer in the new dictionary.
        client (str): Client name to load the cinum map.

    Returns:
        dict: The transformed data in a new dictionary format.
    """

    new_data = original_data.copy()  # Copy the original data to avoid side effects

    # Load the cinum map
    cinummap = load_cinum_map(client, args.config_dir)

    # Function to get updated cinum value
    def get_updated_cinum(cinum_value, append_customer=True):
        updated_value = cinummap.get(cinum_value.lower(), cinum_value)
        if append_customer:
            updated_value += f":{pluspcustomer}"
        return updated_value

    # Insert or update the pluspcustomer value
    new_data['pluspcustomer'] = pluspcustomer

    # Add "customer" field to the main dictionary
    new_data["customer"] = pluspcustomer

    # Modify "cinum" fields in various sections
    if "computersystem" in new_data:
        # Add the IP address
        new_data["computersystem"]["modelobject_contextip"] = ip_data
        if "cinum" in new_data["computersystem"]:
            append_customer_code = new_data["computersystem"]["cinum"].lower(
            ) not in cinummap
            new_data["computersystem"]["cinum"] = get_updated_cinum(
                new_data["computersystem"]["cinum"], append_customer_code)

        for file_system in new_data["computersystem"].get("filesystems", []):
            if "cinum" in file_system:
                append_customer_code = file_system["cinum"].lower(
                ) not in cinummap
                file_system["cinum"] = get_updated_cinum(
                    file_system["cinum"], append_customer_code)

        for intf in new_data["computersystem"].get("interfaces", []):
            if "cinum" in intf:
                append_customer_code = intf["cinum"].lower() not in cinummap
                intf["cinum"] = get_updated_cinum(
                    intf["cinum"], append_customer_code)

        for subs_sytem in new_data["computersystem"].get("subsystems", []):
            if "cinum" in subs_sytem:
                append_customer_code = subs_sytem["cinum"].lower(
                ) not in cinummap
                subs_sytem["cinum"] = get_updated_cinum(
                    subs_sytem["cinum"], append_customer_code)

        os_data = new_data["computersystem"].get("operating_system", {})
        if "cinum" in os_data:
            append_customer_code = os_data["cinum"].lower() not in cinummap
            os_data["cinum"] = get_updated_cinum(
                os_data["cinum"], append_customer_code)

    # Include scan information
    new_data.update(scan_info)

    return new_data


def parse(options, tempdir):
    """ Parse the JSON data and create a new dictionary with transformed data.

    Args:
        options (dict): Options dictionary containing all the necessary parameters.
        tempdir (str): Path to the temporary directory.

    Returns:
        dict: The transformed data in a new dictionary format.
    """

    client = options['customer_options'].get('client', None)
    ip_data = options['customer_options'].get('ip', None)
    change = options['customer_options'].get('change', None)
    pluspcustomer = options['customer_options'].get('pluspcustomer', None)
    if client is not None:
        client = client.upper()

    # Check if the file is compressed
    _, extension = os.path.splitext(options['json_file'])
    # Remove the leading dot from the extension
    extension = extension.lstrip('.')

    if extension in ['zip', 'tgz', 'tar.gz']:
        # Use the passed-in tempdir directly
        uncompressed_file = uncompress(options['json_file'], tempdir)
        with open(uncompressed_file, encoding='utf-8') as file:
            data = json.load(file)
    else:
        with open(options['json_file'], encoding='utf-8') as file:
            data = json.load(file)

    print(f"Original Json:\n{json.dumps(data, indent=2)}\n")

    # Loop through each subsystem and add the new fields
    for subsystem in data.get('subsystems', []):
        key = subsystem.get('classification', '')
        nowclass, product_name, product_manufacturer, u_ibm_last_discovered_status = \
            get_subsystem_details(key, options['app_map'])
        subsystem.update({
            'nowclass': nowclass,
            'product_name': product_name,
            'appserver_vendorname': product_manufacturer,
            'u_ibm_last_discovered_status': u_ibm_last_discovered_status
        })

    scan_info = {"change": change, "ip_data": ip_data}

    # Updated the call to include pluspcustomer
    new = create_new_dict(data, scan_info, ip_data, pluspcustomer, client)

    print("Json to be sent to Maximo:")
    print(json.dumps(new, indent=2))
    print()

    return new


def post_maximo(payload: dict, url: str, auth: dict, customer_data: dict) -> None:
    """
    Sends data using the provided credentials and payload.

    :param payload: The data payload to be sent as a dictionary.
    :param url: The URL to which the data will be sent as a string.
    :param auth: Dictionary containing 'username' and 'password' for authentication.
    :param customer_data: Dictionary containing 'customer' and 'pluspcustomer' data.
    """
    config = {
        'username': auth.get('username', ''),
        'password': auth.get('password', ''),
        'customer': customer_data.get('customer', ''),
        'pluspcustomer': customer_data.get('pluspcustomer', '')
    }

    print("Posting data to Maximo...")
    print(f"URL: {url}")
    print(
        f"Customer: {config['customer']} (Mapped: {config['pluspcustomer']})")
    print(f"User: {config['username']}\n")

    try:
        with requests.Session() as session:
            response = session.post(url, json=payload, auth=(
                config['username'], config['password']), timeout=30)
            response.raise_for_status()

            # Extract relevant details from response content
            response_data = response.json().get("Response", {})
            server_name = response_data.get("Name", "N/A")
            message = response_data.get("Message", "N/A")
            activity_id = response_data.get("ActivityID", "N/A")
            activity_name = response_data.get("ActivityName", "N/A")
            fault_datetime = response_data.get("FaultDateTime", "N/A")

            # Print extracted details
            print("Response Details:")
            print(f"Status Code: {response.status_code}")
            print(f"Server Name: {server_name}")
            print(f"Message: {message}")
            print(f"Activity ID: {activity_id}")
            print(f"Activity Name: {activity_name}")
            print(f"Fault Date and Time: {fault_datetime}")

    except requests.exceptions.RequestException as error:
        print(f"Error posting to Maximo: {error}")


if __name__ == '__main__':
    # Parse arguments
    args = parse_arguments()

    # Grouping the map data loading
    map_data = {
        'app': load_yaml(file="application.map.yaml"),
        'manufacturer': load_yaml(file="manufacturer.map.yaml"),
        'hw': load_yaml(file="hw.map.yaml")
    }

    # Create a temporary work directory to uncompress zip/tgz file
    with create_temporary_directory() as temp_dir_context:
        # Note: This variable seems unused. Consider removing it if it's not required.
        use_tempdir = temp_dir_context

        json_file_path = args.file

        mapped_customer = customers_maximo.get(args.client, None)
        customer_options = {
            'client': args.client,
            'ip': args.ip,
            'change': args.change,
            'pluspcustomer': mapped_customer
        }

        parse_options = {
            'json_file': json_file_path,
            'customer_options': customer_options,
            'app_map': map_data['app'],
            'manufacturer_map': map_data['manufacturer'],
            'hw_map': map_data['hw'],
        }

        payload_data = parse(parse_options, temp_dir_context)
        with open('new_json.json', 'w', encoding='utf-8') as json_file:
            json.dump(payload_data, json_file, indent=4)

        # Send to Maximo
        auth_data = {'username': args.username,
                     'password': args.password}
        customer_details = {'customer': args.client,
                            'pluspcustomer': mapped_customer}

        if mapped_customer:
            post_maximo(
                payload=payload_data,
                url=args.url,
                auth=auth_data,
                customer_data=customer_details
            )

        else:
            print(f"Could not find {args.client} in customers_maximo")

        os.environ.pop('post_user', None)
        os.environ.pop('post_password', None)
