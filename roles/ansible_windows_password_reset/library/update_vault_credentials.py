#!/usr/bin/python
# -*- coding: utf-8 -*-

# @author Rodrigo dos santos Chaves <rschaves@kyndryl.com>
# @copyright (c) Kyndryl Inc. 2021. All Rights Reserved.


ANSIBLE_METADATA = {
    'metadata_version': '1.0',
    'status': ['preview'],
    'supported_by': 'private'
}

DOCUMENTATION = '''
---
module: update_vault_credentials
short_description: Update Vault credentials
version_added: "2.7"
description:
    - "Will connect to Vault to update secrets"
    - "Client must sent the client GSMA present on inventory"
    - "Country is the code present on inventory. Ex: BR, CH, etc"
    - Technology:  
      1. TSM
      2. Windows
author:
- Rodrigo Chaves (rschaves@kyndryl.com>)
'''

EXAMPLES = '''
# Required params
- name: Get Vault credentials
  update_vault_credentials:
    secret: "{{ secret }}"
    hostname: "{{ hostname }}"
    technology: "{{ technology }}"
    client: "{{ client }}"
    country: "{{ country }}"
    vault_url: "{{ vault_url }}"
    vault_role_id: "{{ vault_role_id }}"
    vault_secret_id: "{{ vault_secret_id }}"
  delegate_to: localhost
'''

from ansible.module_utils.basic import AnsibleModule
import requests
import json
import os

# Start reading the main method

# Checking required params passed to the module
def check_required_params(country, client, hostname, technology, instance, secret, module):
  # Verifying country and client
  # 1 - Country must not be None or empty, also must contain 2 characters
  # 2 - Client must not be None or empty, also must contain 3 characters
  if not country or len(country) != 2 or not client or len(client) < 3 :
    module.fail_json(changed=False, msg='Missing required param: client, hostname or country')

  # Verifying required params for Windows or TSM under secret: credential, secret, path and port.
  # All of them must contain some data
  if technology in ['tsm']:
    if not hostname or not instance:
      module.fail_json(changed=False, msg='Missing hostname')
    for param in ['credential', 'secret', 'path', 'port']:
      if not secret.get(param):
        module.fail_json(changed=False, msg='Provide the param "{}"'.format(param))

  # Verifying required params for Windows under secret
  # 1 - In case of domain, the item is_domain should be filled with True and the domain should contain data
  # 2 - Secret must contain the password
  # 3 - In case it's not a domain, hostname is required
  if technology in ['windows']:
    if not secret.get('secret') or (secret.get('is_domain') == True and not secret.get('domain')):
      module.fail_json(changed=False, msg='Missing secret or domain')
    if not hostname and secret.get('is_domain') != True:
      module.fail_json(changed=False, msg='Missing hostname')

# This task will perform an HTTP request to get token from Vault, to perform changes on secrets
def vault_token(vault_role_id, vault_secret_id, vault_url, module):
  headers = {"Content-Type" : "application/json"}
  # It's required the role_id and secret_id that can perform changes on Vault (admin rights)
  data = {"secret_id" : vault_secret_id, "role_id" : vault_role_id}
  # This is the default path for send API request to get the token from Vault
  url = vault_url + "/v1/auth/approle/login"
  # Performing HTTP request for the URL, passing headers (including JSON format) and passing the data with the credentials that has access 
  req = requests.post(url, headers=headers, data=json.dumps(data))
  # Request status 200 means OK, so everything went well and the token must be under request response (req.content)
  if req.status_code == 200:
    return json.loads(req.content)["auth"]["client_token"]
  else:
    # In case an error occurred, this playbook will fail with the request output
    result = {"error_code" : req.status_code, "error_content" : req.content, "url" : url}
    module.fail_json(changed=False, msg="Unable to login in Vault, check assignments", **result)

# This function will send an HTTP request to update/create the secret on Vault according to the technology and data provided
def update_vault_credentials(vault_url, token, secret, instance, technology, hostname, client, country, module):
  # Headers are default for all technologies, including the token retrieved before. Defining request as None, but it will/must be populated
  headers = {'X-Vault-Token' : token}
  req = None
  if technology in ['tsm']:
    # In case of TSM, the path must be: vault_url + /v1/credentials/country/client/application/tsm/hostname/instance
    # The secret is a json with contents: credential, secret, path, port
    url = "{}/v1/credentials/{}/{}/application/tsm/{}/{}".format(vault_url, country, client, hostname, instance)
    req = requests.post(url, headers=headers, data=json.dumps(secret))
  elif technology in ['windows']:
    # In case of Windows, the path must be: 
    # 1 - Is domain? vault_url + /v1/credentials/country/client/connection/domain/domain_name
    # 2 - Is standalone? vault_url + /v1/credentials/country/client/connection/windows/standalone/hostname/secret
    # The secret is a json with the password only
    if secret.get("is_domain"):
      url = "{}/v1/credentials/{}/{}/connection/domain/{}/secret".format(vault_url, country, client, secret.get("domain"))
    else:
      url = "{}/v1/credentials/{}/{}/connection/windows/standalone/{}/secret".format(vault_url, country, client, hostname)

    secret_json = {"secret" : secret.get("secret")}
    req = requests.post(url, headers=headers, data=json.dumps(secret_json))
  # The execution is successful in case the status code is equal 220, 201 or 204
  if req.status_code == 200 or req.status_code == 201 or req.status_code == 204:
    module.exit_json(changed=False, msg='Credentials updated successfully', technology=technology)
  else:
    # Case status code is different, module will fail with the request content
    module.fail_json(changed=False, msg='An error occurred while updating the credentials', request_result=req.content, request_code=req.status_code)

def run_module():
    # This is the acceptable parameters provided to the playbook, not all are required
    module_args = dict(
      vault_url=dict(type='str', required=True),
      vault_role_id=dict(type='str', required=True),
      vault_secret_id=dict(type='str', required=True, no_log=True),
      client=dict(type='str', required=True),
      country=dict(type='str', required=True),
      hostname=dict(type='str', required=False),
      technology=dict(type='str', required=True),
      instance=dict(type='str', required=False),
      secret=dict(type='dict', required=True, no_log=True)
    )

    # the AnsibleModule object will be our abstraction working with Ansible
    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    # Saving module args in vars
    if module.params.get("hostname") != None:
      hostname = module.params.get("hostname").lower()
    else:
      hostname = ""
    if module.params.get("instance") != None:
      instance = module.params.get("instance").lower()
    else:
      instance = ""
    technology = module.params["technology"].lower()
    instance = module.params["instance"]
    secret = module.params["secret"]
    client = module.params["client"].lower()
    country = module.params["country"].lower()
    vault_url = module.params["vault_url"].lower()
    vault_role_id = module.params["vault_role_id"].lower()
    vault_secret_id = module.params["vault_secret_id"].lower()

    # Fail not supported technologies
    if technology.lower() not in ['tsm', 'windows']:
      module.fail_json(changed=False, msg="The technology is not currently supported")

    # Checking params
    check_required_params(country, client, hostname, technology, instance, secret, module)

    # Getting token from Vault
    token = vault_token(vault_role_id, vault_secret_id, vault_url, module)

    # Updating credentials
    update_vault_credentials(vault_url, token, secret, instance, technology, hostname, client, country, module)

# Starting the module
def main():
    run_module()

if __name__ == '__main__':
    main()
