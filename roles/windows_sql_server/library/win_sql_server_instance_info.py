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
module: win_sql_server_instance_info
short_description: Gets local SQL Server instance state on Windows.
description:
- Reads local SQL Server instance state from the target Windows host.
options:
  instance_name:
    description:
    - SQL Server instance name.
    required: yes
    type: str
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: inspect the default SQL Server instance
  win_sql_server_instance_info:
    instance_name: MSSQLSERVER
'''

RETURN = r'''
exists:
  description: Whether the requested SQL Server instance exists.
  returned: always
  type: bool
instance_name:
  description: SQL Server instance name.
  returned: always
  type: str
instance_id:
  description: Internal SQL Server instance identifier from the registry.
  returned: when exists
  type: str
service_name:
  description: SQL Server service name.
  returned: when exists
  type: str
'''
