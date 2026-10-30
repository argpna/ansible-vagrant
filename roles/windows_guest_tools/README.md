# Ansible windows_guest_tools role

## Overview

Installs common Windows guest tools for KVM and libvirt guests: SPICE, WinFSP,
and VirtIO.

## Variables

All variables are optional.

### Feature flags

* `windows_extras.guest_tools.spice_enabled`: Install SPICE guest tools.
* `windows_extras.guest_tools.winfsp_enabled`: Install WinFSP.
* `windows_extras.guest_tools.virtio_enabled`: Install VirtIO guest tools.

### Role defaults

* `windows_guest_tools_temp_dir`: Temporary directory for downloads.
* `windows_guest_tools_virtio_version`: VirtIO archive version.
* `windows_guest_tools_virtio_base_url`: Base URL for VirtIO downloads.
* `windows_guest_tools_virtio_filename`: VirtIO guest tools MSI filename.
* `windows_guest_tools_winfsp_version`: WinFSP version.
* `windows_guest_tools_winfsp_base_url`: Base URL for WinFSP downloads.
* `windows_guest_tools_spice_url`: SPICE guest tools installer URL.

## Example

```yml
- name: install windows guest tools
  hosts: windows
  gather_facts: false
  roles:
    - windows_guest_tools
```
