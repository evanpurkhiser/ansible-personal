# QEMU Unattended Arch Install (Playbook Prep)

Status: deferred for now in favor of `arch-boxes` quick boot workflow.
See `reference/qemu-archbox-quickstart.md` for the currently preferred path.

Deprecation note: this document is kept for historical reference. Current
arch-box flow standardizes on `ttyS0` serial console settings during bootstrap,
so do not treat the `ttyS1` examples below as the active default.

This flow prepares a fresh Arch VM specifically for `ansible-personal` provisioning, matching your server bootstrap conventions.

## What it applies

- UEFI install layout (GPT):
  - `1 GiB` EFI system partition mounted at `/boot`
  - root partition for the remainder
- `linux-lts` kernel (not mainline)
- `mkinitcpio` HOOKS with `kms` removed
- systemd-boot entry with serial console args:
  - `console=tty1 console=ttyS1,115200n8`
- first-boot networking baseline for handoff to Ansible:
  - `/etc/systemd/network/01-internal.network` with `DHCP=yes`
  - `systemd-networkd` + `systemd-resolved` enabled
- SSH bootstrapping for provisioning:
  - `sshd` enabled
  - `PermitRootLogin yes`
  - `PasswordAuthentication yes`
- base bootstrap packages:
  - `neovim bash-completion openssh python`

## Scripts

- Boot VM: `boot-qemu.sh`
- Run unattended install (inside Arch ISO environment): `install-arch-unattended.sh`
- One-command flow (host side): `run-qemu-unattended.sh`

## End-to-end usage

### One command (recommended)

```bash
./run-qemu-unattended.sh --timezone America/Los_Angeles
```

This command:

1. Boots the VM into Arch ISO (headless).
2. Runs `install-arch-unattended.sh` from the live environment automatically.
3. Powers the installer environment off.
4. Reboots the VM from installed disk (without install media).

Dependency note: `run-qemu-unattended.sh` requires `expect` on the host.

### Manual staged flow

1) Boot installer VM:

```bash
./boot-qemu.sh --headless --ssh-port 2223
```

2) In the VM console (or over live-environment SSH), run:

```bash
curl -fsSL http://10.0.2.2:8000/install-arch-unattended.sh -o /root/install-arch-unattended.sh
chmod +x /root/install-arch-unattended.sh
/root/install-arch-unattended.sh --target-disk /dev/nvme0n1 --hostname server --timezone America/Los_Angeles
```

Suggested way to host the script from your repo checkout:

```bash
python -m http.server 8000
```

In QEMU user networking, host is reachable from guest at `10.0.2.2`.

## Optional provisioning key injection

If you want direct key-based root SSH after first boot:

```bash
/root/install-arch-unattended.sh \
  --target-disk /dev/nvme0n1 \
  --authorized-key-file /root/ansible.pub
```

## After reboot

- Remove/detach installer ISO in QEMU boot flow.
- Verify `ip a` and `ip route` inside guest.
- Run your host-side playbook apply against the VM target.
