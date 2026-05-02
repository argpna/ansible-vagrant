#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {
    'metadata_version': '1.1',
    'status': ['preview'],
    'supported_by': 'community',
}

DOCUMENTATION = r'''
---
module: win_adcs_ca_info
short_description: Gets CA certificate details from the local AD CS host.
description:
- Returns the configured CA name, certificate subject, and PEM body for the
  local certification authority certificate.
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: get CA certificate details
  win_adcs_ca_info:
'''

RETURN = r'''
ca_name:
  description: The configured CA common name.
  returned: always
  type: str
subject:
  description: Subject of the CA certificate.
  returned: always
  type: str
pem_body:
  description: PEM body of the CA certificate.
  returned: always
  type: str
'''
