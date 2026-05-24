# Ansible libvirt_host_share role

## Overview

Attach host directories to libvirt guests as virtiofs filesystem devices.

By default the role also requires the target domain to use shared memory
backing, because virtiofs depends on that libvirt guest configuration.

## Variables

### Mandatory Variables

* `libvirt_host_share_list`: List of host share records to attach.

### Optional Variables

* `libvirt_host_share_virsh_bin`: Path to `virsh`. Default: `virsh`
* `libvirt_host_share_vagrant_id_file`: Vagrant libvirt id file used to resolve
  the effective domain name when `libvirt_host_share_domain_name` is not set
* `libvirt_host_share_domain_name`: Explicit libvirt domain name override.
  Default: empty, which means use the Vagrant id file when present, otherwise
  fall back to `inventory_hostname`
* `libvirt_host_share_attach_live_when_running`: Also attach to the live domain
  when the guest is running. Default: `true`
* `libvirt_host_share_require_shared_memory_backing`: Fail unless the domain XML
  contains shared memory backing. Default: `true`
* `libvirt_host_share_xml_dir`: Temporary directory used for rendered device
  XML. Default: `/tmp/libvirt-host-share`


## Example

```yml
- name: attach host shares to MSSQL Windows guests
  hosts: mssql_windows
  gather_facts: false
  roles:
    - role: libvirt_host_share
      vars:
        libvirt_host_share_list:
          - name: sqlmedia
            source: /srv/mssql-media/sql-2022/
            tag: sqlmedia
            guest:
              drive: S:
```
