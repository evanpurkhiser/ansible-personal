## Evan Purkhiser's Ansible Playbooks

[![Build Status](https://github.com/evanpurkhiser/ansible-personal/workflows/lint/badge.svg)](https://github.com/evanpurkhiser/ansible-personal/actions?query=workflow%3Alint)

These are my personal playbooks for configurating my machines.

### Installing Galaxy roles

There are some additional non-core roles that need installed

```
ansible-galaxy install -r requirements.yml
```

### Base Image Bootstrapping

- All machines must be bootstrapped with python 3.x **before** being
  provisioned with any of these playbooks.

- A SSH key should be added to `/root/.ssh/authorized_keys`. All playbooks
  included here make the assumption they are being executed as root.
