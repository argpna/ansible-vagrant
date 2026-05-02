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
module: win_failover_cluster_witness
short_description: Ensures a file share witness is configured for WSFC.
description:
- Ensures the local failover cluster uses the requested file share witness path.
options:
  state:
    description:
    - Desired witness state.
    choices: [present, absent]
    default: present
    type: str
  path:
    description:
    - UNC path for the file share witness.
    type: str
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: ensure the file share witness is configured
  win_failover_cluster_witness:
    path: \\domain-con-01.lab.local\wincl01-witness$

- name: remove the file share witness from quorum
  win_failover_cluster_witness:
    state: absent
'''

RETURN = r'''
changed:
  description: Whether quorum configuration changed.
  returned: always
  type: bool
witness_resource_name:
  description: Current file share witness resource name.
  returned: always
  type: str
witness_share_path:
  description: Current file share witness path.
  returned: always
  type: str
'''
