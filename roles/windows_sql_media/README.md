# Ansible windows_sql_media role

## Overview

Copies SQL Server install media (and optionally the SSMS installer) from a mounted
libvirt host share to a fixed guest-local path. The copy is skipped when the staged file
already matches the source size. The ISO is mounted in `windows_sql_server` role.

The role expects the host share to be attached and mounted already, which is what
[mssql-test-prep.yml](../../playbooks/mssql-test-prep.yml) does before it runs the role.

## Variables

All variables are optional.

* `windows_sql_media_version`: SQL Server version used in default file names.
  Default: `sql_version` of the host
* `windows_sql_media_share_root`: Guest drive root of the SQL media share. Default: `S:\`
* `windows_sql_media_iso_filename`: ISO name inside the share.
  Default: `SQLServer<version>-x64-ENU.iso`
* `windows_sql_media_iso_path`: Staged ISO path.
  Default: `C:\temp\mssql-<version>\<iso filename>`
* `windows_sql_media_ssms_enabled`: Also stage the SSMS installer. Default: `false`
* `windows_sql_media_ssms_share_root`: Guest drive root of the SSMS share. Default: `T:\`
* `windows_sql_media_ssms_filename`: Installer name inside the share. Default: `vs_SSMS.exe`
* `windows_sql_media_ssms_path`: Staged installer path. Default: `C:\temp\ssms-22\vs_SSMS.exe`

## Entrypoints

* `main`: stage the media on the guest.
* `preflight`: run on the libvirt host and fail when a host share is missing from
  `windows_extras.host_shares` or the media file is missing from its source directory.

## Example

```yml
- name: stage SQL Server media
  hosts: mssql_windows_matrix
  gather_facts: false
  roles:
    - role: windows_sql_media
```
