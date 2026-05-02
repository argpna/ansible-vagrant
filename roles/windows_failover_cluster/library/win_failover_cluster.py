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
module: win_failover_cluster
short_description: Ensures a Windows Failover Cluster exists.
description:
- Creates a Windows Failover Cluster when it does not already exist on the
  target node.
options:
  state:
    description:
    - Desired cluster state.
    choices: [present, absent]
    default: present
    type: str
  name:
    description:
    - Cluster name.
    required: yes
    type: str
  nodes:
    description:
    - Cluster node names.
    required: yes
    type: list
    elements: str
  administrative_access_point:
    description:
    - Administrative access point passed to New-Cluster.
    type: str
    default: ActiveDirectoryAndDns
  management_point_network_type:
    description:
    - Management point network type passed to New-Cluster.
    type: str
    default: Singleton
  static_address:
    description:
    - Static cluster IP address when using a singleton management point.
    type: str
  no_storage:
    description:
    - Whether to create the cluster with -NoStorage.
    type: bool
    default: yes
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: ensure the failover cluster exists
  win_failover_cluster:
    name: wincl01
    nodes:
      - win-cluster-n01
      - win-cluster-n02
    administrative_access_point: Dns
    management_point_network_type: Distributed

- name: remove the failover cluster
  win_failover_cluster:
    state: absent
    name: wincl01
    nodes:
      - win-cluster-n01
      - win-cluster-n02
'''

RETURN = r'''
changed:
  description: Whether the cluster was created.
  returned: always
  type: bool
exists:
  description: Whether the cluster exists after the task.
  returned: always
  type: bool
name:
  description: Cluster name.
  returned: always
  type: str
'''
