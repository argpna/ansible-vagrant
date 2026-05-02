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
module: win_connection_adapter_info
short_description: Finds Windows network adapters assigned to an IP address.
description:
- Finds enabled Windows network adapters whose IP configuration contains the
  requested address.
options:
  address:
    description:
    - The IP address to match against enabled adapter configurations.
    required: yes
    type: str
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: find the adapter used for Ansible traffic
  win_connection_adapter_info:
    address: "{{ ansible_host }}"
'''

RETURN = r'''
adapter_names:
  description: Matching adapter connection names.
  returned: always
  type: list
  elements: str
adapter_count:
  description: Number of matching adapters.
  returned: always
  type: int
address:
  description: The requested IP address.
  returned: always
  type: str
'''
