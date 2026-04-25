# QEMU Arch Box Quickstart

Use the official Arch `arch-boxes` basic image to get a VM online quickly for Ansible playbook testing.

## Why this path

- Fast startup with a known-good Arch base.
- SSH is already enabled in the basic image.
- Avoids installer automation complexity while we focus on playbook validation.

## Script

- `qemu/server/boot-qemu-archbox.sh`
- `qemu/server/run-qemu-server-apply.sh` (full two-phase apply orchestration)

The script:

- Downloads `Arch-Linux-x86_64-basic.qcow2` from `images/latest`.
- Verifies SHA256 checksum.
- Creates a writable qcow2 overlay (base image remains immutable).
- Boots with a server-shaped dual-NIC layout and five extra SATA disks by default.
- Forwards host SSH port to guest `22`.

Two-phase network mode for server-like provisioning:

- `--phase bootstrap`: forwards SSH to LAN DHCP address `192.168.0.100` for first boot.
- `--phase post-network`: forwards SSH to LAN static address `10.0.0.1` after the network role intervention step.

By default it uses two `virtio-net` NICs with the same MAC addresses as your real server,
so your `lan0`/`wan0` link rules can apply cleanly while keeping VM networking reliable.

If you want a minimal single-NIC mode, add `--compat-nic`.

## Usage

```bash
qemu/server/boot-qemu-archbox.sh --phase bootstrap --ssh-port 2222
```

Run the full two-phase apply end-to-end:

```bash
qemu/server/run-qemu-server-apply.sh
```

By default, the phase-2 apply resumes at task `Phase two install`.
To force a full second pass, use:

```bash
qemu/server/run-qemu-server-apply.sh --no-phase2-resume
```

`qemu/server/run-qemu-server-apply.sh` defaults to `--ssh-port 2254` and starts from a clean overlay.

SSH in once booted:

```bash
ssh arch@127.0.0.1 -p 2254
```

Default credentials (basic image):

- Username: `arch`
- Password: `arch`

## Useful options

- Reset to clean base state:

```bash
qemu/server/boot-qemu-archbox.sh --reset-overlay
```

- Change resource sizing:

```bash
qemu/server/boot-qemu-archbox.sh --ram 8192 --cpus 8
```

- Skip fake `/dev/zigbee` and `/dev/zwave` symlinks during orchestration:

```bash
qemu/server/run-qemu-server-apply.sh --no-fake-devices
```

## TODO

- Add a pre-provision step to create and persist a realistic `documents` ZFS pool on the 5 SATA lab disks.
- Match production intent by creating RAIDZ2 in lab before playbook apply, so import/mount behavior mirrors real re-apply scenarios.
- Keep this as a dedicated lab bootstrap script (run before `qemu/server/run-qemu-server-apply.sh`) rather than modifying server playbook logic.
