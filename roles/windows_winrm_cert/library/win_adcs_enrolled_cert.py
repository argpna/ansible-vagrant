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
module: win_adcs_enrolled_cert
short_description: Finds an enrolled certificate by issuer and EKU filters.
description:
- Finds the first certificate in C(LocalMachine\My) that matches the requested
  issuer, DNS name, and optional EKU constraints.
options:
  issuer:
    description:
    - The expected certificate issuer.
    required: no
    type: str
  dns_name:
    description:
    - Require the certificate SAN to contain this DNS name.
    required: no
    type: str
  require_client_auth:
    description:
    - Require the certificate to contain the Client Authentication EKU.
    type: bool
    default: no
  require_server_auth:
    description:
    - Require the certificate to contain the Server Authentication EKU.
    type: bool
    default: no
  exclude_kdc_auth:
    description:
    - Exclude certificates that contain the KDC Authentication EKU.
    type: bool
    default: no
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: find an AD CS issued machine certificate
  win_adcs_enrolled_cert:
    issuer: CN=lab-DC01-CA, DC=lab, DC=local
    dns_name: host.lab.local
'''

RETURN = r'''
thumbprint:
  description: The first matching certificate thumbprint.
  returned: always
  type: str
exists:
  description: Whether a matching certificate was found.
  returned: always
  type: bool
subject:
  description: Subject of the first matching certificate.
  returned: when exists
  type: str
'''
