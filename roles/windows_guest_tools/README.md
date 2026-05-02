# Ansible windows_guest_tools role

## Overview

Installs common Windows guest tooling for KVM/libvirt guests, including SPICE,
WinFSP, and VirtIO guest tools.

## Variables

All variables are optional.

### Feature Flags

* `windows_extras.guest_tools.spice_enabled`: Install SPICE guest tools.
* `windows_extras.guest_tools.winfsp_enabled`: Install WinFSP.
* `windows_extras.guest_tools.virtio_enabled`: Install VirtIO guest tools.

### Role Defaults

* `windows_guest_tools_temp_dir`: Temporary directory used for downloads.
* `windows_guest_tools_virtio_version`: VirtIO archive version.
* `windows_guest_tools_virtio_base_url`: Base URL for VirtIO downloads.
* `windows_guest_tools_virtio_filename`: VirtIO guest tools MSI filename.
* `windows_guest_tools_winfsp_version`: WinFSP version.
* `windows_guest_tools_winfsp_base_url`: Base URL for WinFSP.
* `windows_guest_tools_spice_url`: SPICE guest tools installer URL.

## Examples

```yml
- name: install windows guest tools
  hosts: windows
  gather_facts: false
  roles:
    - windows_guest_tools
```
