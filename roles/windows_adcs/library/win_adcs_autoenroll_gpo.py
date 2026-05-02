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
module: win_adcs_autoenroll_gpo
short_description: Imports and configures the AD CS auto-enrollment GPO.
description:
- Imports a known-good GPO backup when missing.
- Patches the domain-specific certificate enrollment policy ID values.
- Ensures the GPO is linked and enforced.
options:
  gpo_name:
    description:
    - Name of the GPO to manage.
    required: yes
    type: str
  backup_path:
    description:
    - Path on the remote host containing the GPO backup manifest and payload.
    required: yes
    type: str
  policy_server_id:
    description:
    - Active Directory certificate enrollment policy server ID for the current domain.
    required: yes
    type: str
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: ensure the AD CS auto-enrollment GPO is configured
  win_adcs_autoenroll_gpo:
    gpo_name: WorkstationCertificateAutoEnroll
    backup_path: C:\temp\WorkstationCertificateAutoEnroll-backup
    policy_server_id: '{00000000-0000-0000-0000-000000000000}'
'''

RETURN = r'''
gpo_name:
  description: Managed GPO name.
  returned: always
  type: str
policy_server_id:
  description: Applied policy server ID.
  returned: always
  type: str
policy_server_key:
  description: Policy server registry key path derived from the backup.
  returned: always
  type: str
changed:
  description: Whether the module changed the GPO.
  returned: always
  type: bool
'''
