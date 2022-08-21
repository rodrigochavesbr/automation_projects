# Next Subsystem Scanner Solution Discovery (SSS)

Subsystem scanner solution discovery has been introduced to provide a manageable method of scanning, collecting and storing subsystem information on a Pan-IOT scale. The alternative to this would be for a technical specialist to access each server in turn and manually search for the subsystems, before storing the resulting information locally. Subsystem data also allows us to be pro-active with increased data quality, identifying out of support software, providing improved technical product data to assist support teams, improved license information, additional database metrics enabling resource management, capacity planning and server availability information.
Results are sent to Maximo and Service Now CMDB, also archived in SFS in Json format.

## Requirements

This role works only for this playbook: GEN_SSS.yml

### SSS Pre-requirements

tmp must contain following files:

File | Path | Description
---------------------------------|-------------------------------------------|-------------
customers.csv | /tmp/sss/runnable/config | Contains the list of customers and Maximo API integration
customer.mapping.csv | /tmp/sss/runnable/config | Contains mapping of the technologies, hosts that will be added to SSS result
unmapped.csv | /tmp/sss/runnable/config  | Contains a list of technologies and specific version that won't be updated in Maximo. This file is update automatically by send2maximo
sss.zip or sss.tar.gz | /tmp/sss/ | Contains the current code that will be executed

## Role Variables

Variable name | Location | Description | Type and values | Usage
--------------|----------|-------------|-----------------|-------------
sss_path | Cloud object Storage | Used to identify files | String with path | /tmp/sss
delete_folder | Extra var | Used to delete SSS folder from endpoint | String with true, yes or false values | delete_folder

# Sdms.properties file variables

Variable | Default| Comments
----------|-----------------|--------
ssl_enabled | false |**Mandatory** This varaible is to enable ssl scan default vbalue is false.
ssl_cold_start | false | **Mandatory** Set this to true if you want to discover what ports are going to be scaned. This mode will list all ports that san be scanned, which can then be added to an exclusion file. set to false to scan for SSL certificates and captures expiry date, length of the key.
ssl_enable_kdb | false | **Mandatory**.parameter accepts “false” or “true”. If it is set to true kdb command will be used on AIX to detect port owners. It may take a long time to get results in this case. The scanner tries to use lsof by default and if lsof is not found it will use kdb.
ssl_enable_pfiles | false | **Mandatory**. If it is set to “true” pfiles command will be used on Solaris to detect port owners. The scanner tries to use lsof by default and if lsof is not found, it will use pfiles.
debug_mode | 'N' | **Mandatory** This parameter accepts Y and N its used to enable debug mode to produce debug logs for scanners
debug | '' | **Mandatory** This parameter works with debug_mode . If debug_mode is set to Y then you can either give value ALL to create log for all the scanners or you can add the subsystem type for indivisual scanner to only debug that scanner
exclude_scan_list| '' | **Mandatory**  its used to enter space-separated list of subsystem identifiers to disable them. Example: AAA ADI BEA IWS
tmp_dir_switch| '' |  **optional** its used to change temp directory to SSS folder. Default is Y.

## Scanner default run directories

Operation System | Default location
--------------|----------
Default directory on Windows | C:\Program Files\ansible\GTS\sss
Default directory on LINUX | /var/opt/ansible/sss
Default directory on AIX | /var/opt/ansible/sss
Default directory on SOLARIS | /var/opt/ansible/sss

## Dependencies

SSS folder in Cloud object Storage (IBM Cloud)

## Example Playbook

```yaml
- name: Scan Sub System
  hosts: "{{ affected_host }}"
  gather_facts: no
  strategy: host_pinned
  ignore_unreachable: true
  pre_tasks:
  - name: Import connection test
    include_role:
      name: connectivity_test

  - name: Error results
    fail:
      msg: "Error code 1 - Unable to connect"
    when: host_access.unreachable is defined and host_access.unreachable

  - name: Check pre requirements
    block:
    - name: Set Ansible intepreter if applicable
      include_role:
        name: python_interpreter
      when: hostvars[inventory_hostname].os != "windows"
      register: python_check

    - name: Gather facts after setup Python interpreter
      setup:
      register: gather_facts_check

    rescue:
    - name: Error results
      debug: msg="{{ 'Error code 2 - Powershell version not supported' if hostvars[inventory_hostname].os == 'windows' else 'Error code 3 - Python not found or invalid' }}"
      register: pre_reqs_failed

  roles:
    - ansible_sss_scan
    - ansible_role_download_object_storage_file
```

## License

Kyndryl Intelectual Property

## Author Information

Rodrigo Chaves rschaves@kyndryl.com
