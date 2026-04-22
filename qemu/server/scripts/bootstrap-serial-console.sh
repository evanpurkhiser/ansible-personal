set -euo pipefail

if ! grep -q "console=ttyS0,115200n8" /etc/default/grub; then
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 console=tty1 console=ttyS0,115200n8"/' /etc/default/grub
fi

if grep -q '^GRUB_TERMINAL=' /etc/default/grub; then
  sed -i 's/^GRUB_TERMINAL=.*/GRUB_TERMINAL="console serial"/' /etc/default/grub
else
  echo 'GRUB_TERMINAL="console serial"' >> /etc/default/grub
fi

if ! grep -q '^GRUB_SERIAL_COMMAND=' /etc/default/grub; then
  echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
fi

grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable serial-getty@ttyS0.service
