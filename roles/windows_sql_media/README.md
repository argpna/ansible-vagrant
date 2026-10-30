# Ansible windows_sql_media role

## Overview

Copies SQL Server install media from a mounted libvirt host share to a fixed
guest-local path. The role can also copy the SQL Server Management Studio (SSMS)
installer. It skips the copy when the staged file already matches the source
size. The `windows_sql_server` role mounts the ISO.

The role requires the host share to be attached and mounted.
[`mssql-test-prep.yml`](../../playbooks/mssql-test-prep.yml) does this before it
runs the role.

## Variables

All variables are optional.

* `windows_sql_media_version`: SQL Server version used in default file names.
  Default: the `sql_version` of the host.
* `windows_sql_media_share_root`: Guest drive root of the SQL media share. Default: `S:\`.
* `windows_sql_media_iso_filename`: ISO name inside the share.
  Default: `SQLServer<version>-x64-ENU.iso`.
* `windows_sql_media_iso_path`: Staged ISO path.
  Default: `C:\temp\mssql-<version>\<iso filename>`.
* `windows_sql_media_ssms_enabled`: Also stage the SSMS installer. Default: `false`.
* `windows_sql_media_ssms_share_root`: Guest drive root of the SSMS share. Default: `T:\`.
* `windows_sql_media_ssms_filename`: Installer name inside the share. Default: `vs_SSMS.exe`.
* `windows_sql_media_ssms_path`: Staged installer path. Default: `C:\temp\ssms-22\vs_SSMS.exe`.

## Entry points

* `main`: Stage the media on the guest.
* `preflight`: Run on the libvirt host and fail when a host share is missing
  from `windows_extras.host_shares` or the media file is missing from its source
  directory.

## Example

```yml
- name: stage SQL Server media
  hosts: mssql_windows_matrix
  gather_facts: false
  roles:
    - role: windows_sql_media
```
