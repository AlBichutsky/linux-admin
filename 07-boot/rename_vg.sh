#!/usr/bin/env bash

# Указываем текущее и новое имя Volume Group
old_vg='VolGroup00'   # текущее имя смотрим через команду vgs
new_vg='OtusRoot'

# Меняем старое название Volume Group на новое
vgrename $old_vg $new_vg

# Заменяем в конфиг.файлах старое название Volume Group на новое
sed -i 's/'$old_vg'/'$new_vg'/g' /etc/fstab /etc/default/grub /boot/grub2/grub.cfg

# Пересоздаем initrd image, чтобы он знал новое название Volume Group
mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)

# После перегружаемся с новым именем Volume Group и проверяем его через команду vgs
sleep 10
reboot