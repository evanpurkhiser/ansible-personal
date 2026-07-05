# QEMU Host Peripheral Inventory

Date: 2026-04-20
Host: `server`
Kernel: `Linux 6.18.22-1-lts x86_64`

## PCI inventory (physical peripherals)

Relevant devices discovered with `lspci -nnk`:

- SATA controller: Intel C236 family AHCI (`8086:a102`) - driver `ahci`
- NIC #1: Intel I219-LM (`8086:15b7`) - driver `e1000e`
- NIC #2: Intel I210 (`8086:1533`) - driver `igb`
- Boot storage controller: Phison PS5021-E21 NVMe (`1987:5021`) - driver `nvme`
- USB controller: Intel 100/C230 xHCI (`8086:a12f`) - driver `xhci_hcd`
- GPU (for console/KVM output): ASPEED Graphics (`1a03:2000`) - driver `ast`

## Block devices

Discovered with `lsblk`:

- `sda` - WDC WD40EFRX-68N32N0 - serial `WD-WCC7K6UF0SVT` - `3.6T` - `sata`
- `sdb` - WDC WD40EFRX-68N32N0 - serial `WD-WCC7K7VCUA40` - `3.6T` - `sata`
- `sdc` - WDC WD40EFRX-68N32N0 - serial `WD-WCC7K7ZX87F5` - `3.6T` - `sata`
- `sdd` - WDC WD40EFRX-68WT0N0 - serial `WD-WCC4E0635208` - `3.6T` - `sata`
- `sde` - WDC WD40EFRX-68N32N0 - serial `WD-WCC7K7VCUHXY` - `3.6T` - `sata`
- `nvme0n1` - Corsair MP600 MINI - serial `232880490001327413C4` - `931.5G` - `nvme`

### Current filesystem layout

- Root disk: `nvme0n1`
  - `nvme0n1p1` mounted at `/boot`
  - `nvme0n1p2` mounted at `/`
- Data pool: ZFS pool `documents` on a 5-disk RAIDZ1
  - `/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K6UF0SVT-part1`
  - `/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7VCUA40-part1`
  - `/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7VCUHXY-part1`
  - `/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K7ZX87F5-part1`
  - `/dev/disk/by-id/ata-WDC_WD40EFRX-68WT0N0_WD-WCC4E0635208-part1`

## Network interfaces

Discovered with `ip` and sysfs:

- `lan0` (UP)
  - MAC: `d0:50:99:c2:9f:07`
  - PCI path: `0000:04:00.0` (Intel I210)
  - Driver: `igb`
  - Addressing seen: `10.0.0.1/24`, global IPv6 + link-local IPv6
- `wan0` (UP)
  - MAC: `d0:50:99:c2:9f:08`
  - PCI path: `0000:00:1f.6` (Intel I219-LM)
  - Driver: `e1000e`
  - Addressing seen: public IPv4 + global IPv6 + link-local IPv6

Additional virtual interfaces present at runtime (not physical): `tailscale0`, `podman0`, and multiple `veth*`.

## USB / serial peripherals

`lsusb`/`usb-devices` are not installed, so inventory was taken from `/sys/bus/usb/devices`.

Detected USB device:

- Vendor: Silicon Labs (`10c4`)
- Product: HubZ Smart Home Controller (`8a2a`)
- Serial: `612029EE`
- Exposed serial interfaces:
  - `/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_612029EE-if00-port0` -> `ttyUSB0`
  - `/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_612029EE-if01-port0` -> `ttyUSB1`

This matches the expected combined Z-Wave/Zigbee style USB controller shape (two serial interfaces).

## VM spec implications

To emulate this host for full-playbook testing:

1. Provide one boot disk (NVMe-like is optional, but keep separate from data pool disks).
2. Provide five additional data disks (SATA bus) with stable serial/model strings.
3. Provide two NICs with stable MACs and predictable names (`lan0`, `wan0`).
4. Provide two serial endpoints for the HubZ role expectations:
   - either USB passthrough of real stick,
   - or two emulated `tty` endpoints mapped to the expected `/dev/serial/by-id/...` symlinks.
5. Preserve `/dev/disk/by-id` style references in provisioning so ZFS and Ansible assumptions stay valid.
