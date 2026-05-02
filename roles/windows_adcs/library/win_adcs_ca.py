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
module: win_adcs_ca
short_description: Ensures an AD CS enterprise root CA is configured.
description:
- Checks whether the local host already has a configured certification
  authority and configures one when missing.
options:
  state:
    description:
    - Desired CA state.
    choices: [present]
    default: present
    type: str
  ca_type:
    description:
    - CA type passed to Install-AdcsCertificationAuthority.
    type: str
    default: EnterpriseRootCa
  crypto_provider_name:
    description:
    - Crypto provider passed to Install-AdcsCertificationAuthority.
    type: str
    default: RSA#Microsoft Software Key Storage Provider
  key_length:
    description:
    - Key length passed to Install-AdcsCertificationAuthority.
    type: int
    default: 2048
  hash_algorithm_name:
    description:
    - Hash algorithm passed to Install-AdcsCertificationAuthority.
    type: str
    default: SHA256
notes:
- This module expects to run with sufficient privileges to configure AD CS.
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: ensure the enterprise root CA is configured
  win_adcs_ca:
'''

RETURN = r'''
configured:
  description: Whether a certification authority is configured after the task.
  returned: always
  type: bool
ca_names:
  description: Configured certification authority names.
  returned: always
  type: list
changed:
  description: Whether the module configured a CA during the run.
  returned: always
  type: bool
'''
