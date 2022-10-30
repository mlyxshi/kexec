# https://github.com/NickCao/netboot/blob/master/flake.nix
{ pkgs, lib, config, modulesPath, ... }: 
let
  # Usage: 
  # install github:mlyxshi/flake hk1 https://linkto/sops/key
  install = pkgs.writeShellApplication {
    name = "install";
    text = ''
      FLAKE_URL=$1
      HOST_NAME=$2
      KEY_URL=$3

      sfdisk /dev/sda <<EOT
      label: gpt
      type="EFI System",        name="BOOT",  size=512M
      type="Linux filesystem", name="NIXOS", size=+
      EOT
      sleep 3

      mkfs.fat -F32 /dev/sda1
      mkfs.ext4 /dev/sda2
      mkdir /mnt
      mount /dev/sda2 /mnt
      mkdir /mnt/boot
      mount /dev/sda1 /mnt/boot
      
      mkdir -p /mnt/var/lib/sops/   
      curl -s "$KEY_URL" -o /mnt/var/lib/sops/age.key

      nixos-install --root /mnt --flake "$FLAKE_URL"#"$HOST_NAME" \
      --no-channel-copy --no-root-passwd \
      --option trusted-public-keys "mlyxshi.cachix.org-1:yc7GPiryyBn0HfiCXdmO1ECWKBhfwrjdIFnRSA4ct7s= cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" \
      --option substituters "https://mlyxshi.cachix.org https://cache.garnix.io" 
    '';
  };
in
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix") # Most VPS, like oracle
    (modulesPath + "/installer/netboot/netboot.nix")
  ];

  boot = {
    initrd.kernelModules = [ "hv_storvsc" ]; # important for azure(hyper-v)
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [ "btrfs" ];
  };

  # TEST
  services.openssh.permitRootLogin = "yes";
  users.users.root = {
    hashedPassword = "$6$fwJZwHNLE640VkQd$SrYMjayP9fofIncuz3ehVLpfwGlpUj0NFZSssSy8GcIXIbDKI4JnrgfMZxSw5vxPkXkAEL/ktm3UZOyPMzA.p0";
  };

  networking.useNetworkd = true;
  networking.firewall.enable = false;

  services.openssh.enable = true;
  services.openssh.authorizedKeysFiles = [ "/run/authorized_keys" ];

  services.getty.autologinUser = "root";

  systemd.services.process-cmdline = {
    wantedBy = [ "multi-user.target" ];
    # 1. pattern matching with the double brackets [source:https://www.baeldung.com/linux/bash-single-vs-double-brackets]
    # 2. Parameter Expansion  [source:man bash]
    script = ''
      export PATH=/run/current-system/sw/bin:$PATH
      xargs -n1 -a /proc/cmdline | while read opt; do
        if [[ $opt = sshkey=* ]]; then
          echo "''${opt#sshkey=}" >> /run/authorized_keys
        fi
        if [[ $opt = script=* ]]; then
          "''${opt#script=}"
        fi
      done
    '';
  };


  system.build.kexecScript = lib.mkForce (pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash
    if ! kexec -v >/dev/null 2>&1; then
      echo "kexec not found: please install kexec-tools" 2>&1
      exit 1
    fi
    SCRIPT_DIR=$( cd -- "$( dirname -- "''${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    kexec --load ''${SCRIPT_DIR}/bzImage \
      --initrd=''${SCRIPT_DIR}/initrd.gz \
      --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} ''${1:+sshkey=''$1}  ''${2:+script=''$2}"
    kexec -e
  '');


  environment.systemPackages = [
    pkgs.htop
    install
  ];
}
