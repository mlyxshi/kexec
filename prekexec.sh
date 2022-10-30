#! /usr/bin/env bash

apt install -y wget kexec-tools

wget https://github.com/mlyxshi/kexec/releases/download/latest/kexec-boot
wget https://github.com/mlyxshi/kexec/releases/download/latest/initrd.gz
wget https://github.com/mlyxshi/kexec/releases/download/latest/bzImage

chmod +x ./kexec-boot
# 1 required: sshkey
# 2 optional: install script URL
# 3 optional: install script parameter1 -> SOPS_AGE_KEY_URL
# 4 optional: install script parameter2-> Telegram Bot Token
# 5 optional: install script parameter3 -> Telegram Chat ID
./kexec-boot "${1:+$1}" "${2:+$2}" "${3:+$3}" "${4:+$4}" "${5:+$5}"