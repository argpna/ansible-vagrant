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
module: win_dns_host_record_cleanup
short_description: Removes unexpected AD DNS A records for a host.
description:
- Removes A records for a hostname from a DNS zone when their address does not
  match the expected address.
options:
  zone_name:
    description:
    - DNS zone name.
    required: yes
    type: str
  record_name:
    description:
    - DNS record name to clean up.
    required: yes
    type: str
  expected_ip:
    description:
    - The only IP address that should remain for the A record.
    required: yes
    type: str
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: remove unexpected A records for the current host
  win_dns_host_record_cleanup:
    zone_name: "{{ domain.name }}"
    record_name: "{{ inventory_hostname }}"
    expected_ip: "{{ ansible_host }}"
'''

RETURN = r'''
zone_name:
  description: DNS zone name.
  returned: always
  type: str
record_name:
  description: DNS record name.
  returned: always
  type: str
expected_ip:
  description: Expected A record IP address.
  returned: always
  type: str
removed_ips:
  description: IP addresses removed from the DNS zone.
  returned: always
  type: list
  elements: str
'''
