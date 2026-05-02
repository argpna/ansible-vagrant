#!/usr/bin/env python3
"""Dynamic inventory for the lab.

This module is the single resolver for the raw inventory layout. Downstream
consumers should use the resolved host data from --list / --host instead of
depending on the structure of inventory/hosts.yml.

Examples:
  inventory/inventory.py --host ansible-con-01
  inventory/inventory.py --list
"""

import argparse
import copy
import ipaddress
import json
import os
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[1]
INVENTORY_PATH = ROOT / "inventory" / "hosts.yml"
INVENTORY_D_PATH = ROOT / "inventory" / "hosts.d"
GROUP_VARS_DIR = ROOT / "inventory" / "group_vars"
GROUP_VARS_ALL = GROUP_VARS_DIR / "all"

ALLOWED_OS = {"linux", "windows"}
ALLOWED_INTERFACE_ROLES = {"management", "sql"}


class InventoryValidationError(ValueError):
    pass


def load_yaml(path: Path) -> dict[str, Any]:
    """Load a YAML file into a mapping"""
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def merge_hash(a: Any, b: Any) -> dict[str, Any]:
    """Deep-merge two mappings"""
    a = a if isinstance(a, dict) else {}
    b = b if isinstance(b, dict) else {}
    out = copy.deepcopy(a)
    for key, value in b.items():
        if isinstance(out.get(key), dict) and isinstance(value, dict):
            out[key] = merge_hash(out[key], value)
        else:
            out[key] = copy.deepcopy(value)
    return out


def merge_inventory_tree(a: Any, b: Any, path: str = "") -> dict[str, Any]:
    """Merge raw inventory trees and reject duplicate host definitions"""
    a = a if isinstance(a, dict) else {}
    b = b if isinstance(b, dict) else {}
    out = copy.deepcopy(a)

    for key, value in b.items():
        key_path = f"{path}.{key}" if path else str(key)
        if key == "hosts" and isinstance(out.get(key), dict) and isinstance(value, dict):
            duplicates = sorted(set(out[key]) & set(value))
            if duplicates:
                raise InventoryValidationError(
                    f"Duplicate host definitions at {key_path}: {', '.join(duplicates)}"
                )
            out[key] = merge_hash(out[key], value)
        elif isinstance(out.get(key), dict) and isinstance(value, dict):
            out[key] = merge_inventory_tree(out[key], value, key_path)
        else:
            out[key] = copy.deepcopy(value)

    return out


def load_group_vars(path: Path) -> dict[str, Any]:
    """Load group vars from a file or a directory of YAML files"""
    if path.is_dir():
        out: dict[str, Any] = {}
        for item in sorted(path.glob("*.yml")):
            out = merge_hash(out, load_yaml(item))
        return out
    return load_yaml(path)


def load_group_vars_entry(group_name: str) -> dict[str, Any]:
    """Load one group_vars entry and reject file-plus-directory conflicts"""
    file_path = GROUP_VARS_DIR / f"{group_name}.yml"
    dir_path = GROUP_VARS_DIR / group_name

    if file_path.is_file() and dir_path.is_dir():
        raise InventoryValidationError(
            f"Conflicting group_vars definitions for {group_name!r}; use either "
            f"{file_path.name} or {dir_path.name}/, not both"
        )
    if file_path.is_file():
        return load_yaml(file_path)
    if dir_path.is_dir():
        return load_group_vars(dir_path)
    return {}


def load_named_group_vars() -> dict[str, dict[str, Any]]:
    """Load group vars for named groups under group_vars/"""
    out: dict[str, dict[str, Any]] = {}
    file_groups = {item.stem for item in GROUP_VARS_DIR.glob("*.yml") if item.stem != "all"}
    dir_groups = {item.name for item in GROUP_VARS_DIR.iterdir() if item.is_dir() and item.name != "all"}
    for group_name in sorted(file_groups | dir_groups):
        out[group_name] = load_group_vars_entry(group_name)
    return out


def load_inventory() -> dict[str, Any]:
    """Load the raw inventory tree from hosts.yml and hosts.d"""
    inventory = load_yaml(INVENTORY_PATH)
    if INVENTORY_D_PATH.is_dir():
        for item in sorted(INVENTORY_D_PATH.glob("*.yml")):
            inventory = merge_inventory_tree(inventory, load_yaml(item))
    return inventory


def env_str(key: str, default: str | None = None) -> str | None:
    """Read a trimmed environment variable with a default"""
    value = os.environ.get(key)
    if value is None or not value.strip():
        return default
    return value


def select_ansible_vars(vars_hash: Any) -> dict[str, Any]:
    """Keep only ansible_* keys from a mapping"""
    if not isinstance(vars_hash, dict):
        return {}
    return {key: value for key, value in vars_hash.items() if str(key).startswith("ansible_")}


def valid_ipv4(value: Any) -> bool:
    """Return true when value parses as an IPv4 address"""
    try:
        ipaddress.IPv4Address(str(value))
        return True
    except Exception:
        return False


def build_group_graph(inventory: dict[str, Any], group_vars: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """Build the group graph from raw inventory and named group vars.

    The result keeps per-group vars, direct hosts, and parent/child links so
    later phases can derive inherited vars and effective host memberships.
    """
    groups: dict[str, dict[str, Any]] = {}
    seen_host_defs: dict[str, str] = {}

    def ensure_group(group_name: str) -> dict[str, Any]:
        return groups.setdefault(group_name, {"vars": {}, "hosts": {}, "children": set(), "parents": set()})

    def walk(node: Any, group_name: str, parent_name: str | None = None) -> None:
        if not isinstance(node, dict):
            node = {}

        group = ensure_group(group_name)
        if parent_name:
            parent = ensure_group(parent_name)
            parent["children"].add(group_name)
            group["parents"].add(parent_name)

        group["vars"] = merge_hash(group["vars"], node.get("vars") or {})

        node_hosts = node.get("hosts")
        if isinstance(node_hosts, dict):
            for host_name, host_vars in node_hosts.items():
                if host_name in seen_host_defs:
                    raise InventoryValidationError(
                        f"Host {host_name}: duplicate host definition in groups "
                        f"{seen_host_defs[host_name]!r} and {group_name!r}"
                    )
                seen_host_defs[host_name] = group_name
                group["hosts"][host_name] = copy.deepcopy(host_vars or {})

        children = node.get("children")
        if isinstance(children, dict):
            for child_name, child in children.items():
                walk(child, child_name, group_name)

    walk(inventory.get("all", inventory), "all")

    for group_name, group in groups.items():
        group["vars"] = merge_hash(group_vars.get(group_name), group["vars"])
        group["children"] = sorted(group["children"])
        group["parents"] = sorted(group["parents"])

    return groups


def group_depths(group_graph: dict[str, dict[str, Any]]) -> dict[str, int]:
    """Compute breadth-first depths for groups"""
    depths = {"all": 0}
    queue = ["all"]
    while queue:
        group_name = queue.pop(0)
        for child_name in group_graph.get(group_name, {}).get("children", []):
            child_depth = depths[group_name] + 1
            if child_name not in depths or child_depth < depths[child_name]:
                depths[child_name] = child_depth
                queue.append(child_name)
    return depths


def ancestor_groups(group_graph: dict[str, dict[str, Any]], group_name: str) -> set[str]:
    """Return all ancestor groups for one group"""
    ancestors: set[str] = set()
    stack = list(group_graph.get(group_name, {}).get("parents", []))
    while stack:
        parent_name = stack.pop()
        if parent_name in ancestors:
            continue
        ancestors.add(parent_name)
        stack.extend(group_graph.get(parent_name, {}).get("parents", []))
    return ancestors


def flatten_hosts(group_graph: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """Flatten the group graph into per-host vars and memberships.

    Host vars are built by merging ancestor group vars, direct group vars, and
    host-local vars in that order.
    """
    hosts: dict[str, dict[str, Any]] = {}
    depths = group_depths(group_graph)

    for group_name, group in group_graph.items():
        for host_name, host_vars in group.get("hosts", {}).items():
            host_groups = ancestor_groups(group_graph, group_name) | {group_name}
            var_groups = sorted(host_groups, key=lambda item: (depths.get(item, 999), item))

            merged_vars: dict[str, Any] = {}
            for var_group in var_groups:
                merged_vars = merge_hash(merged_vars, group_graph.get(var_group, {}).get("vars"))
            merged_vars = merge_hash(merged_vars, host_vars or {})

            hosts[host_name] = {
                "vars": merged_vars,
                "groups": sorted(host_groups - {"all"}),
            }
    return hosts


def network_profile(all_vars: dict[str, Any]) -> str:
    """Resolve the active network profile"""
    default_profile = all_vars.get("network_profile") or "default"
    return env_str("NETWORK_PROFILE", str(default_profile)) or "default"


def network_profiles(all_vars: dict[str, Any]) -> dict[str, Any]:
    """Return the configured network profiles mapping"""
    profiles = all_vars.get("network_profiles")
    return profiles if isinstance(profiles, dict) else {}


def network_config(all_vars: dict[str, Any]) -> dict[str, Any]:
    """Return the configured lab networks mapping"""
    networks = all_vars.get("networks")
    return networks if isinstance(networks, dict) else {}


def validate_interfaces(host_name: str, host: dict[str, Any]) -> list[dict[str, Any]]:
    """Validate and shape host's declared interfaces.

    The result keeps only the fields the resolved inventory output exposes
    and enforces uniqueness plus the single-management interface rule.
    """
    interfaces = host.get("network_interfaces")
    if not isinstance(interfaces, list) or not interfaces:
        raise InventoryValidationError(f"Host {host_name}: network_interfaces must be a non-empty list")

    out: list[dict[str, Any]] = []
    seen_names: set[str] = set()
    seen_ips: set[str] = set()
    management_count = 0

    for idx, item in enumerate(interfaces):
        if not isinstance(item, dict):
            raise InventoryValidationError(f"Host {host_name}: interface[{idx}] must be a mapping")

        name = str(item.get("name") or "").strip()
        network = str(item.get("network") or "").strip()
        ip = str(item.get("ip") or "").strip()
        role = str(item.get("role") or "").strip().lower()
        mac = item.get("mac")

        if not name:
            raise InventoryValidationError(f"Host {host_name}: interface[{idx}] missing required field 'name'")
        if not network:
            raise InventoryValidationError(f"Host {host_name}: interface[{idx}] missing required field 'network'")
        if not ip:
            raise InventoryValidationError(f"Host {host_name}: interface[{idx}] missing required field 'ip'")
        if not role:
            raise InventoryValidationError(f"Host {host_name}: interface[{idx}] missing required field 'role'")
        if role not in ALLOWED_INTERFACE_ROLES:
            expected = ", ".join(sorted(ALLOWED_INTERFACE_ROLES))
            raise InventoryValidationError(
                f"Host {host_name}: interface[{idx}] role {role!r} is invalid, expected one of: {expected}"
            )
        if not valid_ipv4(ip):
            raise InventoryValidationError(f"Host {host_name}: interface[{idx}] ip {ip!r} is not a valid IPv4 address")
        if name in seen_names:
            raise InventoryValidationError(f"Host {host_name}: duplicate interface name {name!r}")
        if ip in seen_ips:
            raise InventoryValidationError(f"Host {host_name}: duplicate interface ip {ip!r}")

        if role == "management":
            management_count += 1

        seen_names.add(name)
        seen_ips.add(ip)
        out.append(
            {
                "name": name,
                "network": network,
                "ip": ip,
                "mac": mac,
                "role": role,
            }
        )

    if management_count > 1:
        raise InventoryValidationError(
            f"Host {host_name}: at most one interface may have role='management', found {management_count}"
        )

    return out


def connection_interface(host_name: str, interfaces: list[dict[str, Any]], ansible_host: str) -> dict[str, Any]:
    """Find the declared interface that matches ansible_host"""
    matches = [interface for interface in interfaces if interface.get("ip") == ansible_host]
    if len(matches) != 1:
        raise InventoryValidationError(
            f"Host {host_name}: ansible_host {ansible_host!r} must match exactly one declared interface IP, found {len(matches)}"
        )
    return matches[0]


def management_interface(host_name: str, interfaces: list[dict[str, Any]]) -> dict[str, Any] | None:
    """Return the management interface when present"""
    mgmt = [interface for interface in interfaces if interface.get("role") == "management"]
    if len(mgmt) > 1:
        raise InventoryValidationError(
            f"Host {host_name}: expected at most one management interface after validation, found {len(mgmt)}"
        )
    return mgmt[0] if mgmt else None


def interface_names(interfaces: list[dict[str, Any]]) -> list[str]:
    """Return interface names in order"""
    return [str(interface.get("name")) for interface in interfaces]


def attachment_profile_for_host(host_name: str, host: dict[str, Any], profile_name: str) -> list[str]:
    """Return attached interface names for one network profile.

    Profiles are optional per-host overrides that let the active topology
    choose a subset of declared interfaces.
    """
    profiles = host.get("network_profiles")
    if profiles is None:
        return []
    if not isinstance(profiles, dict):
        raise InventoryValidationError(f"Host {host_name}: network_profiles must be a mapping when present")

    profile = profiles.get(profile_name)
    if profile is None:
        return []
    if not isinstance(profile, dict):
        raise InventoryValidationError(f"Host {host_name}: network_profiles[{profile_name!r}] must be a mapping")

    attach = profile.get("attach_interfaces")
    if not isinstance(attach, list) or not attach:
        raise InventoryValidationError(
            f"Host {host_name}: network_profiles[{profile_name!r}].attach_interfaces must be a non-empty list"
        )
    return [str(item) for item in attach]


def attached_interfaces(
    host_name: str,
    host: dict[str, Any],
    interfaces: list[dict[str, Any]],
    connection_iface: dict[str, Any],
    profile_name: str,
) -> list[dict[str, Any]]:
    """Resolve the interfaces attached for the active profile.

    When a host has no profile-specific attachment override, all declared
    interfaces stay attached. Profile overrides must still include the
    connection interface.
    """
    selected_names = attachment_profile_for_host(host_name, host, profile_name)
    if not selected_names:
        return copy.deepcopy(interfaces)

    known_names = {str(interface.get("name")) for interface in interfaces}
    unknown = [name for name in selected_names if name not in known_names]
    if unknown:
        raise InventoryValidationError(
            f"Host {host_name}: profile {profile_name!r} references unknown interface names: {', '.join(unknown)}"
        )

    selected = [interface for interface in interfaces if str(interface.get("name")) in selected_names]
    if str(connection_iface.get("name")) not in selected_names:
        raise InventoryValidationError(
            f"Host {host_name}: profile {profile_name!r} must include connection interface {connection_iface.get('name')!r}"
        )

    return copy.deepcopy(selected)


def validate_host_contract(host_name: str, host: dict[str, Any], host_groups: list[str], networks: dict[str, Any]) -> list[dict[str, Any]]:
    """Validate one host against the resolved inventory rules.

    This checks base host requirements, interface/network consistency, and the
    extra rules tied to specific group memberships such as control-node and
    MSSQL AG hosts.
    """
    os_name = str(host.get("os") or "").lower()
    if os_name not in ALLOWED_OS:
        expected = ", ".join(sorted(ALLOWED_OS))
        raise InventoryValidationError(f"Host {host_name}: os must be one of {expected}, got {os_name!r}")

    ansible_host = str(host.get("ansible_host") or "").strip()
    if not ansible_host:
        raise InventoryValidationError(f"Host {host_name}: ansible_host is required")
    if not valid_ipv4(ansible_host):
        raise InventoryValidationError(f"Host {host_name}: ansible_host {ansible_host!r} is not a valid IPv4 address")

    vagrant_box = str(host.get("vagrant_box") or "").strip()
    if not vagrant_box:
        raise InventoryValidationError(f"Host {host_name}: vagrant_box is required")

    interfaces = validate_interfaces(host_name, host)
    for interface in interfaces:
        network = str(interface.get("network"))
        if network not in networks:
            raise InventoryValidationError(
                f"Host {host_name}: interface {interface['name']!r} references unknown lab network {network!r}"
            )

    connection_iface = connection_interface(host_name, interfaces, ansible_host)
    mgmt = management_interface(host_name, interfaces)

    if "control_node" in host_groups or "domain_controller" in host_groups:
        if mgmt is None:
            raise InventoryValidationError(
                f"Host {host_name}: members of control_node or domain_controller must define role='management'"
            )
        if mgmt.get("ip") != connection_iface.get("ip"):
            raise InventoryValidationError(
                f"Host {host_name}: control_node/domain_controller ansible_host must match the management interface"
            )

    if "mssql_windows_ag" in host_groups:
        sql_interfaces = [interface for interface in interfaces if interface.get("role") == "sql"]
        if not sql_interfaces:
            raise InventoryValidationError(f"Host {host_name}: members of mssql_windows_ag must define at least one role='sql' interface")

    return interfaces


def build_resolved_inventory() -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    """Build the resolved group graph and per-host inventory data.

    Loads raw inventory inputs, merges global and group defaults, validates
    hosts against the active network profile, and produces the hostvars
    used by Ansible and Vagrant.
    """
    inventory = load_inventory()
    named_group_vars = load_named_group_vars()
    all_vars = load_group_vars_entry("all")

    group_graph = build_group_graph(inventory, named_group_vars)
    hosts = flatten_hosts(group_graph)
    resolved_hosts: dict[str, dict[str, Any]] = {}
    profile_name = network_profile(all_vars)
    profiles = network_profiles(all_vars)
    networks = network_config(all_vars)

    if profile_name not in profiles:
        expected = ", ".join(sorted(profiles.keys()))
        raise InventoryValidationError(f"Unknown NETWORK_PROFILE={profile_name!r}, expected one of: {expected}")

    for host_name, meta in hosts.items():
        host = copy.deepcopy(meta["vars"])
        host["inventory_hostname"] = host_name
        interfaces = validate_host_contract(host_name, host, meta["groups"], networks)
        connection_iface = connection_interface(host_name, interfaces, str(host.get("ansible_host")))
        mgmt = management_interface(host_name, interfaces)
        attached = attached_interfaces(host_name, host, interfaces, connection_iface, profile_name)
        attached_networks = sorted({str(item.get("network")) for item in attached if item.get("network")})
        profile_networks = {str(item) for item in profiles[profile_name].get("networks", [])}
        unmanaged_attached_networks = [network for network in attached_networks if network not in profile_networks]
        if unmanaged_attached_networks:
            raise InventoryValidationError(
                f"Host {host_name}: attached networks are not managed by NETWORK_PROFILE={profile_name!r}: "
                f"{', '.join(unmanaged_attached_networks)}"
            )

        # Merge connection/provider defaults but keep unknown inventory keys intact
        provider = all_vars.get("provider_options") or {}
        os_name = str(host.get("os") or "").lower()
        named_defaults = named_group_vars.get(os_name, {})
        provider = merge_hash(provider, named_defaults.get(f"{os_name}_defaults", {}).get("provider_options"))
        provider = merge_hash(provider, host.get("provider_options"))

        connection = merge_hash({}, select_ansible_vars(named_defaults))
        connection = merge_hash(connection, host.get("connection"))

        resolved = merge_hash(host, connection)
        resolved.pop("network_interfaces", None)
        resolved.pop("network_profiles", None)
        resolved["inventory_hostname"] = host_name
        resolved["ansible_host"] = str(host.get("ansible_host"))
        resolved["mac"] = connection_iface.get("mac") or host.get("mac")
        resolved["network_profile"] = profile_name
        resolved["interfaces"] = {
            "declared": interfaces,
            "attached": interface_names(attached),
            "connection": str(connection_iface.get("name")),
            "management": str(mgmt.get("name")) if mgmt else None,
        }
        resolved["attached_networks"] = attached_networks
        resolved["provider_options"] = provider
        resolved["groups"] = meta["groups"]
        resolved_hosts[host_name] = resolved

    root_vars = merge_hash(group_graph.get("all", {}).get("vars"), all_vars)
    root_vars["network_profile"] = profile_name
    group_graph.setdefault("all", {"vars": {}, "hosts": {}, "children": [], "parents": []})["vars"] = root_vars
    return group_graph, resolved_hosts


def build_ansible_json(group_graph: dict[str, dict[str, Any]], resolved_hosts: dict[str, dict[str, Any]]) -> dict[str, Any]:
    """Render the resolved inventory in Ansible JSON format.

    Hostvars come from the resolved host data, while group sections keep
    direct hosts, merged vars, and child groups.
    """
    groups: dict[str, Any] = {"_meta": {"hostvars": {}}}

    for host_name, vars_hash in resolved_hosts.items():
        hostvars = copy.deepcopy(vars_hash)
        hostvars.pop("groups", None)
        groups["_meta"]["hostvars"][host_name] = hostvars

    for group_name in sorted(group_graph):
        group = group_graph[group_name]
        groups.setdefault(group_name, {})
        if isinstance(group.get("hosts"), dict):
            groups[group_name]["hosts"] = sorted(group["hosts"].keys())
        if isinstance(group.get("vars"), dict):
            groups[group_name]["vars"] = copy.deepcopy(group["vars"])
        children = group.get("children")
        if children:
            groups[group_name]["children"] = sorted(children)

    return groups


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--host")
    args = parser.parse_args()

    inventory, resolved_hosts = build_resolved_inventory()
    ansible_json = build_ansible_json(inventory, resolved_hosts)

    if args.host:
        print(json.dumps(ansible_json["_meta"]["hostvars"].get(args.host, {}), indent=2, sort_keys=True))
        return

    print(json.dumps(ansible_json, indent=2, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except InventoryValidationError as exc:
        raise SystemExit(f"inventory/inventory.py validation error: {exc}")
