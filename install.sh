#! /usr/bin/env bash

# You need tweak this script to your needs
set -o errexit
set -o nounset
set -o pipefail

HOST=$1
KEY_URL=$2
FLAKE_URL="github:mlyxshi/flake"

sfdisk /dev/sda <<EOT
label: gpt
type="EFI System",        name="BOOT",  size=512M
type="Linux filesystem", name="NIXOS", size=+
EOT

sleep 3

mkfs.fat -F32 /dev/sda1
mkfs.ext4 -F /dev/sda2

mkdir /mnt
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

[[ -n "$2" ]] && mkdir -p /mnt/var/lib/age/ && curl -s "$KEY_URL" -o /mnt/var/lib/age/sshkey

nixos-install --root /mnt --flake $FLAKE_URL#$HOST --no-channel-copy --no-root-passwd \
--option extra-trusted-public-keys "cache.mlyxshi.com:qbWevQEhY/rV6wa21Jaivh+Lw2AArTFwCB2J6ll4xOI=" \
--option extra-substituters "http://cache.mlyxshi.com" -v

[[ -e /run/ssh_host_ed25519_key ]] && cp /run/ssh_host_ed25519_key /mnt/etc/ssh/ssh_host_ed25519_key && cp /run/ssh_host_ed25519_key.pub /mnt/etc/ssh/ssh_host_ed25519_key.pub

[[ -n "$3" && -n "$4" ]] && curl -X POST "https://api.telegram.org/bot$3/sendMessage" -d chat_id=$4 -d text="<b>Install NixOS Completed</b>%0A$SYSTEM_CLOSURE" -d parse_mode=html

reboot