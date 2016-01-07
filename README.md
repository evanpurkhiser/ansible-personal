## Evan Purkhiser's Ansible Playbooks

These are my personal playbooks for configurating my machines.

### Base Image Bootstrapping

All machines must be boostrapped to include the following software **before**
being provisioned with any of these playbooks:

 - git
 - python 2.x
 - sudo

A SSH key should be added to `/root/.ssh/authorized_keys`. All playbooks
included here make the assumption they are being executed as root.
