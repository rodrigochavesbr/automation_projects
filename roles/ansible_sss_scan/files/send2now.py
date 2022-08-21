#!/usr/bin/env python3

import time

import argparse
import os
import sys
import json
import re
import requests
import yaml
import tempfile
import tarfile
import zipfile

# Mapping of incoming ICD classes to ServiceNow classes
osnow = {
  "ci.linuxcomputersystem":    'cmdb_ci_linux_server',
  "ci.aixcomputersystem":      'cmdb_ci_aix_server',
  "ci.sunsparccomputersystem": 'cmdb_ci_solaris_server',
  "ci.hpuxcomputersystem":     'cmdb_ci_hpux_server',
  "ci.windowscomputersystem":  'cmdb_ci_win_server'
}

app_map_default = {
  "apa": {"nowclass": "cmdb_ci_apache_web_server", "manufacturer":"Apache Software Foundation" },
  "aaa": {"nowclass": "cmdb_ci_appl", "manufacturer":"Open Source" },
  "afs": {"nowclass": "cmdb_ci_appl", "manufacturer":"Open Source" },
  "axg": {"nowclass": "cmdb_ci_appl", "manufacturer":"Axway Software" },
  "bes": {"nowclass": "cmdb_ci_appl", "manufacturer":"BlackBerry Limited" },
  "bpm": {"nowclass": "cmdb_ci_app_server", "manufacturer":"IBM" },
  "ccm": {"nowclass": "cmdb_ci_appl", "manufacturer":"Microsoft Corporation" },
  "cft": {"nowclass": "cmdb_ci_appl", "manufacturer":"Axway Software" },
  "dir": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "ina": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "isa": {"nowclass": "cmdb_ci_appl", "manufacturer":"Microsoft Corporation" },
  "it6": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "mal": {"nowclass": "cmdb_ci_appl", "manufacturer":"F-Secure Corporation" },
  "nco": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "noc": {"nowclass": "cmdb_ci_appl", "manufacturer":"NetApp, Inc." },
  "nsm": {"nowclass": "cmdb_ci_appl", "manufacturer":"NetApp, Inc." },
  "oem": {"nowclass": "cmdb_ci_appl", "manufacturer":"Oracle Corporation" },
  "sbe": {"nowclass": "cmdb_ci_appl", "manufacturer":"Broadcom Inc." },
  "sbl": {"nowclass": "cmdb_ci_app_server", "manufacturer":"Oracle Corporation" },
  "sck": {"nowclass": "cmdb_ci_appl", "manufacturer":"Open Source" },
  "smm": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "tdm": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "tem": {"nowclass": "cmdb_ci_appl", "manufacturer":"HCL Technologies Limited" },
  "tim": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "tip": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "tpc": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "tpm": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "tsm": {"nowclass": "cmdb_ci_appl", "manufacturer":"IBM" },
  "tws": {"nowclass": "cmdb_ci_appl", "manufacturer":"HCL Technologies Limited" },
  "wpr": {"nowclass": "cmdb_ci_appl", "manufacturer":"Open Source" },
  "wts": {"nowclass": "cmdb_ci_appl", "manufacturer":"Microsoft Corporation" },
  "xfb": {"nowclass": "cmdb_ci_appl", "manufacturer":"Axway Software" },
  "dom": {"nowclass": "cmdb_ci_appl_domino", "manufacturer":"HCL Technologies Limited" },
  "jbs": {"nowclass": "cmdb_ci_app_server_jboss", "manufacturer":"IBM" },
  "oas": {"nowclass": "cmdb_ci_app_server_ora_ias", "manufacturer":"Oracle Corporation" },
  "tom": {"nowclass": "cmdb_ci_app_server_tomcat", "manufacturer":"Open Source" },
  "bea": {"nowclass": "cmdb_ci_app_server_weblogic", "manufacturer":"Oracle Corporation" },
  "was": {"nowclass": "cmdb_ci_app_server_websphere", "manufacturer":"IBM" },
  "wlp": {"nowclass": "cmdb_ci_app_server_websphere", "manufacturer":"IBM" },
  "adi": {"nowclass": "cmdb_ci_appl_active_directory", "manufacturer":"Microsoft Corporation" },
  "ctx": {"nowclass": "cmdb_ci_appl_citrix_xenapp", "manufacturer":"Citrix Systems, Inc." },
  "wmb": {"nowclass": "cmdb_ci_appl_ibm_wmb", "manufacturer":"IBM" },
  "mqm": {"nowclass": "cmdb_ci_appl_ibm_wmq", "manufacturer":"IBM" },
  "sap": {"nowclass": "cmdb_ci_appl_sap", "manufacturer":"SAP SE" },
  "shp": {"nowclass": "cmdb_ci_appl_sharepoint", "manufacturer":"Microsoft Corporation" },
  "wps": {"nowclass": "cmdb_ci_appl_websphere_portal", "manufacturer":"HCL Technologies Limited" },
  "db2": {"nowclass": "cmdb_ci_db_db2_instance", "manufacturer":"IBM" },
  "ifx": {"nowclass": "cmdb_ci_db_instance", "manufacturer":"IBM" },
  "mxd": {"nowclass": "cmdb_ci_db_instance", "manufacturer":"SAP SE" },
  "msl": {"nowclass": "cmdb_ci_db_mssql_instance", "manufacturer":"Microsoft Corporation" },
  "ors": {"nowclass": "cmdb_ci_db_mssql_reporting", "manufacturer":"Microsoft Corporation" },
  "myl": {"nowclass": "cmdb_ci_db_mysql_instance", "manufacturer":"Oracle Corporation" },
  "ora": {"nowclass": "cmdb_ci_db_ora_instance", "manufacturer":"Oracle Corporation" },
  "pgs": {"nowclass": "cmdb_ci_db_postgresql_instance", "manufacturer":"Open Source" },
  "syb": {"nowclass": "cmdb_ci_db_syb_instance", "manufacturer":"SAP SE" },
  "exc": {"nowclass": "cmdb_ci_exchange_service_component", "manufacturer":"Microsoft Corporation" },
  "kvm": {"nowclass": "cmdb_ci_kvm", "manufacturer":"Open Source" },
  "iis": {"nowclass": "cmdb_ci_microsoft_iis_web_server", "manufacturer":"Microsoft Corporation" },
  "ngx": {"nowclass": "cmdb_ci_nginx_web_server", "manufacturer":"Open Source" },
  "vce": {"nowclass": "cmdb_ci_vcenter", "manufacturer":"VMware, Inc." },
  "smb": {"nowclass": "cmdb_ci_appl", "manufacturer":"Open Source" },
  "ssh": {"nowclass": "cmdb_ci_appl", "manufacturer":"Open Source" },
  "sdo": {"nowclass": "cmdb_ci_appl", "manufacturer":"Open Source" } 
}

def parse_arguments():
  parser = argparse.ArgumentParser(description='Parse json and send to ServiceNow')
  parser.add_argument('-c', '--client', dest='client', required=True, 
                      help='GSMA Client code with three letters')
  parser.add_argument('-f', '--file', dest='file', required=True,
                      help='Full path to file to be parsed and posted to ServiceNow')
  parser.add_argument('-i', '--ip', dest='ip', 
                      help='IP used to connected to this server, in ansible, usually ansible_host')
  parser.add_argument('--change', dest='change', 
                      help='Identification of change responsible to activate this device')
  parser.add_argument('-u', '--url', dest='url', required=True, help='ServiceNow URL')
  parser.add_argument('--username', dest='username', required=True, help='ServiceNow username')
  parser.add_argument('-p', '--password', dest='password', required=True, help='ServiceNow password')
  return parser.parse_args()


def create_temporary_directory():
  try:
    tempdir = tempfile.TemporaryDirectory()
  except OSError as error:
    print('Could not create temporary directory {}.'.format(error))
    exit(1)
  print("Using temporary directory {}".format(tempdir.name))
  return tempdir.name


# Uncompress file
def uncompress(file=None, tempdir=None):

  host, extension = os.path.basename(file).split('.')

  if extension == 'tgz':
    try:
      with tarfile.open(file) as tar:
        tar.extract(host+'.json', path=tempdir)
    except Exception as error:
      print("ERROR uncompressing {}: {}".format(file, error))
      exit(1)
  else:
    try:
      with zipfile.ZipFile(file) as zip:
        zip.extract(host+'.json', path=tempdir)
    except Exception as error:
      print("ERROR uncompressing {}: {}".format(file, error))
      exit(1)

  print("{} successfully uncompressed.".format(file))
  return os.path.join(tempdir, host + ".json")


def load_yaml(file=None):
  # Get script path
  file_fullpath = os.path.join(os.path.dirname(os.path.realpath(__file__)), file)

  try:
    with open(file_fullpath) as yaml_file:
      try:
        data = yaml.safe_load(yaml_file)
      except yaml.YAMLError as error:
        print("ERROR parsing {}: {}".format(file_fullpath, error))
        exit(1)
  except OSError as error:
    print("ERROR opening {}: {}".format(file_fullpath, error))
    exit(1)

  print("{} successfully loaded.".format(file_fullpath))
  return data

def append_status(status: None, text: None):
  if status == 'OK':
    new_text = text
  else:
    new_text = "{}, {}".format(status, text)
  return new_text

# Parse incoming json and add more info like client and ServiceNow classes
def parse(json_file=None, client=None, ip=None, change=None, app_map=None, manufacturer_map=None, hw_map=None):
  u_ibm_last_discovered_status = 'OK'
  client = client.upper()

  with open(json_file) as file:
    data = json.load(file)

  print("Original Json: \n{}\n".format(json.dumps(data, indent=2)))

  scantime = re.sub(r"^(.{10}).(.{8}).*", r"\1 \2", data["scan_time"])

  manufacturer = data["computersystem"]["computersystem_manufacturer"].strip()
  if manufacturer.lower() in manufacturer_map:
    manufacturer = manufacturer_map[manufacturer.lower()]
  else:
    u_ibm_last_discovered_status = append_status(status=u_ibm_last_discovered_status, 
      text="Manufacturer '{}' is not mapped".format(manufacturer))

  # removing multiple spaces of models
  model = ' '.join(data["computersystem"]["computersystem_model"].split())
  if manufacturer.lower() in hw_map and model.lower() in hw_map[manufacturer.lower()]:
    model = hw_map[manufacturer.lower()][model.lower()]
  else:
    u_ibm_last_discovered_status = append_status(status=u_ibm_last_discovered_status, 
      text="Manufacturer '{}' or model '{}' are not mapped".format(manufacturer, model))

  new = {
    "discovery_source": "NEXT Discovery",
    "scan_time": scantime,
    "parent_class": 'cmdb_ci_server',
    "customer": client,
    "classification": osnow[data["computersystem"]["classification"]],
    "hostname": data["computersystem"]["hostname"].lower(),
    "cinum": data["computersystem"]["cinum"],
    "ciname": data["computersystem"]["ciname"].lower(),
    "computersystem_name": data["computersystem"]["computersystem_name"].lower(),
    "computersystem_fqdn": data["computersystem"]["computersystem_fqdn"].lower() if "computersystem_fqdn" in data["computersystem"] and data["computersystem"]["computersystem_fqdn"] else data["computersystem"]["computersystem_name"].lower(),
    "computersystem_virtual": data["computersystem"]["computersystem_virtual"],
    "computersystem_cputype": data["computersystem"]["computersystem_cputype"].strip(),
    "computersystem_cpucoresenabled": data["computersystem"]["computersystem_cpucoresenabled"],
    "computersystem_numcpus": data["computersystem"]["computersystem_numcpus"],
    "computersystem_memorysize": data["computersystem"]["computersystem_memorysize"],
    "computersystem_swapmensize": data["computersystem"]["computersystem_swapmensize"],
    "computersystem_manufacturer": manufacturer,
    "computersystem_serialnumber": data["computersystem"]["computersystem_serialnumber"].strip(),
    "computersystem_model": model,
    "computersystem_timezone": data["computersystem"]["computersystem_timezone"],
    "operatingsystem_osname": data["computersystem"]["operating_system"]["operatingsystem_osname"].strip(),
    "operatingsystem_osversion": data["computersystem"]["operating_system"]["operatingsystem_osversion"].strip(),
    "operatingsystem_servicepack": data["computersystem"]["operating_system"]["operatingsystem_servicepack"].strip(),
    "operatingsystem_osmode": data["computersystem"]["operating_system"]["operatingsystem_osmode"].strip(),
    "operatingsystem_kernelversion": data["computersystem"]["operating_system"]["operatingsystem_kernelversion"].strip(),
    "computersystem_monitoring_agent": "N",
    "computersystem_inventory_agent": "N",
    "u_ibm_last_discovered_status": u_ibm_last_discovered_status,
    "interfaces": [],
    "filesystems": []
  }

  if "computersystem_domain" in data["computersystem"] and data["computersystem"]["computersystem_domain"]:
    new["os_domain"] = data["computersystem"]["computersystem_domain"]

  if change:
    new["change"] = change

  if ip:
    new["ip_address"] = ip

  # CEP for Windows. For Unix, it will look for Sudo on subsystems below.
  if new["classification"] == "cmdb_ci_win_server":
    new["ismbr_cep1_1"] = "OS / BUILT-IN"
    new["ismbr_cep1_2"] = "SEE OS VERSION"

  # Network interfaces
  if "interfaces" in data["computersystem"]:
    for interface in data["computersystem"]["interfaces"]:
      if (interface["networkinterface_ipaddress"] != '' and
         interface["networkinterface_ipaddress"] != 'N/A' and
         interface["networkinterface_ipaddress"] != 'UNSPEC' and
         interface["networkinterface_ipaddress"] != 'ETHERNET'):

        new["interfaces"].append(
          {
            "discovery_source":                   "NEXT Discovery",
            "classification":                     'cmdb_ci_network_adapter',
            "relation":                           'contains',
            "customer":                           client,
            "name":                               interface["cinum"],
            "ciname":                             new["ciname"],
            "networkinterface_ipaddress":         interface["networkinterface_ipaddress"],
            "networkinterface_netmask":           interface["networkinterface_netmask"],
            "networkinterface_interfacename":     interface["networkinterface_interfacename"],
            "networkinterface_adminstate":        interface["networkinterface_adminstate"],
            "networkinterface_ianainterfacetype": interface["networkinterface_ianainterfacetype"],
            "networkinterface_physicaladdress":   interface["networkinterface_physicaladdress"]
          }
        )

  # Filesystems
  if "filesystems" in data["computersystem"]:
    for fs in data["computersystem"]["filesystems"]:
      new["filesystems"].append(
        {
          "discovery_source":                   "NEXT Discovery",
          "classification":        'cmdb_ci_file_system',
          "relation":              'contains',
          "name":                  re.sub(r"^[^:]*:", "", fs["cinum"]),
          "ciname":                new["ciname"],
          "customer":              client,
          "filesystem_type":       fs["filesystem_type"].lower(),
          "filesystem_capacity":   str(int(fs["filesystem_capacity"])*1024*1024),
          "filesystem_freespace":  str(int(fs["filesystem_availablespace"])*1024*1024),
          "filesystem_mountpoint": fs["filesystem_mountpoint"]
        }
      )

  # Subsystems
  if "subsystems" in data["computersystem"]:
    for subsystem in data["computersystem"]["subsystems"]:

      apptype = subsystem["type"].lower()
      key = "{}.{}".format(apptype, subsystem["appserver_productname"].lower())

      # Update ITM flag if subsystem type is it6
      if apptype == 'it6':
        new["computersystem_monitoring_agent"] = "Y"

      # Update BigFix flag if subsystem type is tem
      if apptype == 'tem':
        new["computersystem_inventory_agent"] = "Y"

      # Update CEP values if subsystem type is sudo
      if apptype == 'sdo':
        new["ismbr_cep1_1"] = "SUDO"
        new["ismbr_cep1_2"] = subsystem["appserver_productversion"]

      # Skip subsystems we don't want to upload.
      if apptype in [ 'cmc', 'dmn', 'fra', 'ilk', 'itm', 'oic', 'osl', 'rsa',
                      'scm', 'shs', 'ssk', 'ssl', 't4d', 'tm5', 'kvm' ]:
        continue

      # Skip subsystems client/agents/fta:
      if apptype in [ 'afs', 'ccm', 'dir', 'ina', 'it6', 'mal', 'sbe', 'smm', 'tem', 'tsm', 't4d'] \
         and ("client" in key or "agent" in key or "fta" in key):
        continue

      # Use app_map values if it exists:
      if key in app_map:

        nowclass = app_map[key]["nowclass"]

        # Skip if nowclass is empty, it indicates we must not upload this subsystem.
        if not nowclass:
          continue

        product_name = app_map[key]["product"]
        product_manufacturer = app_map[key]["manufacturer"]
        u_ibm_last_discovered_status = "OK"

      # Or, use what we have from scan with default values
      else:
        nowclass = app_map_default[apptype]["nowclass"]
        product_name = subsystem["appserver_productname"]
        product_manufacturer = app_map_default[apptype]["manufacturer"]
        u_ibm_last_discovered_status = "Subsystem '{}' is not mapped to a nice name. Need to add to appmapping file.".format(key)

      # Add this subsystem entry if it doesn't exist
      if nowclass not in new:
        new[nowclass] = []

      # for these apptypes, avoid to add more than one.
      elif apptype in [ 'iis', 'shp', 'exc', 'ctx', 'was' ]:
        continue

      version = 'N/A' if subsystem["appserver_productversion"] == '0.0.0' else subsystem["appserver_productversion"]
      short_description = "{} {}".format(product_name, version)

      # Create base subsystem data
      subsystem_data = {
          "discovery_source":            "NEXT Discovery",
          "ciname":                       new["ciname"],
          "u_ibm_cmdb_ci":                new["ciname"],
          "name":                         subsystem["cinum"],
          "customer":                     client,
          "company":                      client,
          "appserver_productname":        product_name,
          "u_ibm_product_name":           product_name,
          "appserver_productversion":     version,
          "version":                      version,
          "short_description":            short_description,
          "last_discovered":              scantime,
          "manufacturer":                 product_manufacturer,
          "u_ibm_last_discovered_status": u_ibm_last_discovered_status,
          "relationship": [
            {
              "inverse_relation": "Runs on::Runs",
              "name":             new["ciname"],
              "parent":           subsystem["cinum"],
              "code":             client
            }
          ]
        }

      if "path" in subsystem:
        subsystem_data["install_directory"] = subsystem["path"]

      if "port" in subsystem:
        subsystem_data["tcp_port"] = subsystem["port"]

      # Add db instance if this is a db
      if re.search("^cmdb_ci_db.*_instance$", nowclass):
        _host, _apptype, instance = subsystem["cinum"].split(":")
        subsystem_data["u_ibm_instance_db_name"] = instance

      # Add sid instance if this is SAP
      if nowclass.startswith("cmdb_ci_appl_sap"):
        _host, sid = subsystem["ciname"].split(":")
        subsystem_data["sid"] = sid

      # Append subsystem_data to json
      new[nowclass].append(subsystem_data)

  print("Json to be sent to ServiceNow:")
  print(json.dumps(new, indent=2))
  print()

  return new


# Post payload to ServiceNow
def post(payload=None, url=None, username=None, password=None):
  print("Posting to ServiceNow at {} with user {}".format(url, username))
  try:
    r = requests.post(url, json=payload, auth=(username, password), timeout=30)
    print("status_code {}, content: {}".format(r.status_code, r.content))
  except Exception as e:
    print("Error posting to ServiceNow: {}".format(e))


if __name__ == '__main__':

  # Parse arguments
  args = parse_arguments()

  # Load mappings, they must be on same path of this script.
  app_map = load_yaml(file="application.map.yaml")
  manufacturer_map = load_yaml(file="manufacturer.map.yaml")
  hw_map = load_yaml(file="hw.map.yaml")

  # Create a temporary work directory to uncompress zip/tgz file
  # It is automatically removed at end of script
  tempdir = create_temporary_directory()
    
  # Uncompress file, it returns json file full path to be processed
  json_file = uncompress(file=args.file, tempdir=tempdir)

  # Work on json to send to ServiceNow
  payload = parse(json_file=json_file, client=args.client, ip=args.ip, change=args.change, 
                  app_map=app_map, manufacturer_map=manufacturer_map, hw_map=hw_map)

  # Send to ServiceNow
  post(payload=payload, url=args.url, username=args.username, password=args.password)
