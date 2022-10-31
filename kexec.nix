# https://github.com/NickCao/netboot/blob/master/flake.nix
{ pkgs, lib, config, modulesPath, ... }: 
let
  # build and install system closure directly, high-end machine only
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

      if [[ -n "$4" && -n "$5" ]]; then
        MESSAGE="<b>Install NixOS Completed</b>%0A$HOST_NAME"
        URL="https://api.telegram.org/bot$4/sendMessage"
        curl -X POST "$URL" -d chat_id="$5" -d text="$MESSAGE" -d parse_mode=html
      fi

      reboot
    '';
  };
in
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix") # Most QEMU_KVM VPS, like oracle
    (modulesPath + "/installer/netboot/netboot.nix")
  ];

  system.stateVersion = "22.11";

  boot = {
    initrd.kernelModules = [ "hv_storvsc" ]; # important for azure(hyper-v)
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [ "btrfs" ];
  };

  networking.useNetworkd = true;
  networking.firewall.enable = false;

  services.openssh.enable = true;
  services.openssh.authorizedKeysFiles = [ "/run/authorized_keys" ];

  services.getty.autologinUser = "root";

  systemd.services.process-cmdline-ssh = {
    wantedBy = [ "multi-user.target" ];
    script = ''
      IFS=$'\n'  

      for opt in $(xargs -n1 -a /proc/cmdline);
      do
        if [[ $opt = sshkey=* ]]; then
          sshkey="''${opt#sshkey=}" 
          break       
        fi
      done

      echo $sshkey >> /run/authorized_keys
    '';
  };


  systemd.services.process-cmdline-script = {
    wantedBy = [ "multi-user.target" ];
    # 1. pattern matching with the double brackets [source:https://www.baeldung.com/linux/bash-single-vs-double-brackets]
    # 2. Parameter Expansion  [source:man bash]
    # 3. IFS=$'\n'  make newlines the only separator [https://unix.stackexchange.com/questions/7011/how-to-loop-over-the-lines-of-a-file]
    script = ''
      export PATH=/run/current-system/sw/bin:$PATH

      IFS=$'\n'

      for opt in $(xargs -n1 -a /proc/cmdline);
      do
        if [[ $opt = script_url=* ]]; then
          script_url="''${opt#script_url=}"
        fi

        if [[ $opt = script_arg1=* ]]; then
          script_arg1="''${opt#script_arg1=}"
        fi

        if [[ $opt = script_arg2=* ]]; then
          script_arg2="''${opt#script_arg2=}"
        fi

        if [[ $opt = script_arg3=* ]]; then
          script_arg3="''${opt#script_arg3=}"
        fi
      done


      echo "SCRIPT_URL: $script_url"
      echo "SCRIPT_ARG1: $script_arg1"
      echo "SCRIPT_ARG2: $script_arg2"
      echo "SCRIPT_ARG3: $script_arg3"

      sleep 5 # wait dhcp network?

      echo "SCRIPT_CONTENT------------------------------------------------------------------------"
      if [[ -n "$script_url" ]]; then
        curl -sL $script_url
      fi
      echo "--------------------------------------------------------------------------------------"
      
      if [[ -n "$script_url" ]]; then
        curl -sL $script_url | bash -s $script_arg1 $script_arg2 $script_arg3
      fi
    '';
  };


  system.build.kexecScript = lib.mkForce (pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash

    echo "Support Debian/Ubuntu. For other distros, please install wget kexec-tools mannually"

    # delete old version
    rm bzImage
    rm initrd.gz
    rm kexec-boot 

    apt install -y wget kexec-tools

    wget https://github.com/mlyxshi/kexec/releases/download/latest/initrd.gz
    wget https://github.com/mlyxshi/kexec/releases/download/latest/bzImage

    if ! kexec -v >/dev/null 2>&1; then
      echo "kexec not found: please install kexec-tools" 2>&1
      exit 1
    fi

    extraCmdLine=""
    for arg in "$@"
    do
      # sshkey add double quotes
      if [[ $arg = sshkey=* ]]; then
        arg="sshkey=\"''${arg#sshkey=}\""
      fi   
      extraCmdLine+="$arg "
    done


    kexec --load ./bzImage \
      --initrd=./initrd.gz \
      --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} $extraCmdLine"
    kexec -e
  '');


  environment.systemPackages = [
    pkgs.htop
    install
  ];
}
