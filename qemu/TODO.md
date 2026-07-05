# QEMU TODO

1. Improve GitHub Actions image caching for faster test startup.
   - Cache a prepared VM state that is as close as possible to "ready to run playbook".
   - Investigate whether snapshot/resume-style approaches (disk snapshot, memory state, or equivalent) are practical and reliable in Actions.
   - Reuse that prepared state across subsequent workflow runs to reduce boot/provisioning time.

2. Add a pre-apply ZFS disk setup step for parity with real hardware.
   - Use the existing 5 data disks in the VM.
   - Create and configure a RAIDZ2 pool before the full playbook apply.
   - Ensure the lab workflow mirrors expected production apply conditions.
