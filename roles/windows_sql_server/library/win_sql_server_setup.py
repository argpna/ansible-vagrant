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
module: win_sql_server_setup
short_description: Ensures a SQL Server instance is installed with setup.exe.
description:
- Checks whether the requested SQL Server instance already exists and runs
  setup.exe when it does not.
options:
  state:
    description:
    - Desired instance state.
    choices: [present]
    default: present
    type: str
  media_path:
    description:
    - Directory containing SQL Server setup.exe.
    required: yes
    type: str
  instance_name:
    description:
    - SQL Server instance name.
    required: yes
    type: str
  features:
    description:
    - SQL Server setup feature identifiers.
    required: yes
    type: list
    elements: str
  sqlsysadminaccounts:
    description:
    - Accounts to grant sysadmin during setup.
    type: list
    elements: str
  security_mode:
    description:
    - SQL Server authentication mode.
    - When set to C(Windows), setup.exe is run without C(/SECURITYMODE)
      because SQL Server only accepts that switch for mixed mode.
    choices: [Windows, SQL]
    default: Windows
    type: str
  sa_password:
    description:
    - SA password when security_mode is SQL.
    type: str
  sqlsvc_account:
    description:
    - SQL Server Database Engine service account.
    type: str
  sqlsvc_password:
    description:
    - Password for sqlsvc_account.
    type: str
  agtsvc_account:
    description:
    - SQL Server Agent service account.
    type: str
  agtsvc_password:
    description:
    - Password for agtsvc_account.
    type: str
  browser_startup_type:
    description:
    - SQL Browser startup type.
    choices: [Automatic, Disabled, Manual]
    default: Disabled
    type: str
  update_enabled:
    description:
    - Whether to enable SQL Server product updates during setup.
    type: bool
    default: no
  update_source:
    description:
    - Update source path when update_enabled is true.
    type: str
  product_key:
    description:
    - Product key to pass to setup.exe when needed.
    type: str
  install_shared_dir:
    description:
    - Shared feature install directory.
    type: str
  install_shared_wow_dir:
    description:
    - Shared WOW directory.
    type: str
  instance_dir:
    description:
    - Instance root directory.
    type: str
  install_sql_data_dir:
    description:
    - Default SQL data root directory.
    type: str
  sql_user_db_dir:
    description:
    - Default user database data directory.
    type: str
  sql_user_db_log_dir:
    description:
    - Default user database log directory.
    type: str
  sql_temp_db_dir:
    description:
    - TempDB data directory.
    type: str
  sql_temp_db_log_dir:
    description:
    - TempDB log directory.
    type: str
author:
- Arun Gopinath
'''

EXAMPLES = r'''
- name: install SQL Server Database Engine
  win_sql_server_setup:
    media_path: C:\SQLServer2022
    instance_name: MSSQLSERVER
    features:
      - SQLEngine
'''

RETURN = r'''
changed:
  description: Whether setup.exe was invoked.
  returned: always
  type: bool
exists:
  description: Whether the requested instance exists after the task.
  returned: always
  type: bool
instance_name:
  description: SQL Server instance name.
  returned: always
  type: str
reboot_required:
  description: Whether setup returned a reboot-required exit code.
  returned: always
  type: bool
exit_code:
  description: setup.exe exit code when setup ran.
  returned: when changed
  type: int
setup_stdout_path:
  description: Path on the remote host containing redirected setup stdout.
  returned: when changed
  type: str
setup_stderr_path:
  description: Path on the remote host containing redirected setup stderr.
  returned: when changed
  type: str
'''
