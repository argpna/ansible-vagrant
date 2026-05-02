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
module: win_failover_cluster_info
short_description: Gets local Windows Failover Cluster state.
description:
- Reads local Windows Failover Cluster state from the target node.
options:
  name:
    description:
    - Optional cluster name to try when local Get-Cluster does not resolve.
    type: str
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: get cluster state
  win_failover_cluster_info:
    name: wincl01
'''

RETURN = r'''
exists:
  description: Whether a cluster could be opened.
  returned: always
  type: bool
name:
  description: Cluster name.
  returned: when exists
  type: str
cluster_group_state:
  description: State of the core Cluster Group.
  returned: when exists
  type: str
nodes:
  description: Node states as name:state strings.
  returned: always
  type: list
  elements: str
'''
