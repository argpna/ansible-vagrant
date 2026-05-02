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
module: win_winrm_listener_info
short_description: Gets the current WinRM HTTPS listener certificate thumbprint.
description:
- Reads the local WinRM HTTPS listener and returns the configured certificate
  thumbprint when present.
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: inspect the current WinRM HTTPS listener
  win_winrm_listener_info:
'''

RETURN = r'''
exists:
  description: Whether an HTTPS listener exists.
  returned: always
  type: bool
certificate_thumbprint:
  description: The configured certificate thumbprint.
  returned: when exists
  type: str
address:
  description: The listener address selector.
  returned: when exists
  type: str
'''
