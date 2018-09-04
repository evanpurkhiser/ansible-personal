## Evan Purkhiser's Ansible Playbooks

These are my personal playbooks for configurating my machines.

### Base Image Bootstrapping

- All machines must be bootstrapped with python 3.x **before** being
  provisioned with any of these playbooks.

- A SSH key should be added to `/root/.ssh/authorized_keys`. All playbooks
  included here make the assumption they are being executed as root.
