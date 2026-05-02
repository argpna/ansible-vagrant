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
module: win_dns_registration
short_description: Controls DNS registration across Windows DNS client adapters.
description:
- Enables DNS registration on the requested adapter and disables it on other
  non-loopback DNS client interfaces.
options:
  adapter_name:
    description:
    - Adapter interface alias that should register this connection's address.
    required: yes
    type: str
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: keep DNS registration only on the connection adapter
  win_dns_registration:
    adapter_name: "{{ windows_connection_adapter_name }}"
'''

RETURN = r'''
adapter_name:
  description: Adapter interface alias selected for DNS registration.
  returned: always
  type: str
updated_interfaces:
  description: Interface aliases whose DNS registration setting was changed.
  returned: always
  type: list
  elements: str
'''
