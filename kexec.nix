# https://github.com/NickCao/netboot/blob/master/flake.nix
# 1. pattern matching with the double brackets [source:https://www.baeldung.com/linux/bash-single-vs-double-brackets]
# 2. Parameter Expansion  [source:man bash]

{ pkgs, lib, config, modulesPath, ... }:
let
  kernelTarget = pkgs.stdenv.hostPlatform.linux-kernel.target;
  kernelName = lib.concatStringsSep "-" [ "${kernelTarget}" "${pkgs.stdenv.hostPlatform.system}" ];
  initrdName = lib.concatStringsSep "-" [ "initrd" "${pkgs.stdenv.hostPlatform.system}" ];
  kexecScriptName = lib.concatStringsSep "-" [ "kexec" "${pkgs.stdenv.hostPlatform.system}" ];

  kexecScript = pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash
    set -e   
    echo "Support Debian/Ubuntu/NixOS. For other distros, install wget kexec-tools manually"

    command -v apt > /dev/null && apt install -y wget kexec-tools
    ! command -v wget > /dev/null && echo "wget not found: please install wget" && exit 1
    ! command -v kexec > /dev/null && echo "kexec not found: please install kexec-tools" && exit 1

    wget -q --show-progress -N https://github.com/mlyxshi/kexec/releases/download/latest/${initrdName}
    wget -q --show-progress -N https://github.com/mlyxshi/kexec/releases/download/latest/${kernelName}

    for arg in "$@"; do cmdScript+="$arg "; done
  
    [[ -f /etc/ssh/ssh_host_ed25519_key ]] && host_key=$(cat /etc/ssh/ssh_host_ed25519_key|base64|tr -d '\n') && host_key_pub=$(cat /etc/ssh/ssh_host_ed25519_key.pub|base64|tr -d '\n')
    
    for i in /home/$SUDO_USER/.ssh/authorized_keys /root/.ssh/authorized_keys /etc/ssh/authorized_keys.d/root; do
      if [[ -e $i && -s $i ]]
      then 
        echo "--------------------------------------------------"
        echo "Get SSH key from: $i"
        sshkey=$(cat $i|base64|tr -d '\n')
        break
      fi     
    done

    echo "--------------------------------------------------"
    echo "sshkey(base64): $sshkey"
    echo "--------------------------------------------------"
    echo "host_key(base64): $host_key"
    echo "--------------------------------------------------"
    echo "host_key_pub(base64): $host_key_pub"
    echo "--------------------------------------------------"
    echo "script_info: $@"
    echo "--------------------------------------------------"

    echo "Wait..."
    echo "After SSH connection lost, ssh root@ip and enjoy NixOS!"

    kexec --load ./${kernelName} --initrd=./${initrdName}  --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} ''${sshkey:+sshkey=''$sshkey}   ''${host_key:+host_key=''$host_key}  ''${host_key_pub:+host_key_pub=''$host_key_pub}  $cmdScript"  
    kexec -e
  '';
in
{

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix") # Most QEMU VPS, like Oracle
    (modulesPath + "/installer/netboot/netboot.nix")
  ];

  system.stateVersion = "22.11";

  environment.systemPackages = with pkgs; [
    htop
    lf # Terminal File Browser
    neovim-unwrapped
  ];

  environment.sessionVariables.EDITOR = "nvim";
  environment.etc."lf/lfrc".text = ''
    set hidden true
    set number true
    set drawbox true
    set dircounts true
    set incsearch true
    set period 1

    map q   quit
    map Q   quit
    map D   delete
    map <enter> open
  '';


  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.initrd.kernelModules = [ "hv_storvsc" ]; # Important for Azure(Hyper-v)
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = [ "btrfs" ];

  networking.useNetworkd = true;
  networking.firewall.enable = false;
  systemd.network.wait-online.anyInterface = true;
  services.getty.autologinUser = "root";

  services.openssh.enable = true;
  services.openssh.authorizedKeysFiles = [ "/run/authorized_keys" ];
  services.openssh.hostKeys = [{
    path = "/run/ssh_host_ed25519_key";
    type = "ed25519";
  }];

  # Overwrite /run/ssh_host_ed25519_key and /run/ssh_host_ed25519_key.pub to the original one, so we don't need "ssh-keygen -R IP"
  # https://github.com/NixOS/nixpkgs/blob/26eb67abc9a7370a51fcb86ece18eaf19ae9207f/nixos/modules/services/networking/ssh/sshd.nix#L435
  systemd.services.sshd.preStart = lib.mkForce ''
    mkdir -m 0755 -p /etc/ssh

    export PATH=/run/current-system/sw/bin:$PATH

    for opt in $(xargs -n1 -a /proc/cmdline)
    do
      [[ $opt = sshkey=* ]] && sshkey="''${opt#sshkey=}" && continue       
      [[ $opt = host_key=* ]] && host_key="''${opt#host_key=}" && continue  
      [[ $opt = host_key_pub=* ]] && host_key_pub="''${opt#host_key_pub=}" && continue
    done

    [[ -n $sshkey ]] && echo $sshkey | base64 -d > /run/authorized_keys   
    
    if [[ -n $host_key && -n $host_key_pub ]]
    then
      echo $host_key | base64 -d > /run/ssh_host_ed25519_key
      echo $host_key_pub | base64 -d > /run/ssh_host_ed25519_key.pub

      chmod 600 /run/ssh_host_ed25519_key
      chmod 644 /run/ssh_host_ed25519_key.pub   
    else 
      ssh-keygen -t "ed25519" -f "/run/ssh_host_ed25519_key" -N ""  
    fi
  '';


  systemd.services.process-cmdline-script = {
    after = [ "network-online.target" ];
    script = ''
      export PATH=/run/current-system/sw/bin:$PATH

      for opt in $(xargs -n1 -a /proc/cmdline)
      do
        [[ $opt = script_url=* ]] && script_url="''${opt#script_url=}" && continue
        [[ $opt = script_arg1=* ]] && script_arg1="''${opt#script_arg1=}" && continue
        [[ $opt = script_arg2=* ]] && script_arg2="''${opt#script_arg2=}" && continue
        [[ $opt = script_arg3=* ]] && script_arg3="''${opt#script_arg3=}" && continue   
      done

      echo "SCRIPT_URL: $script_url"
      echo "SCRIPT_ARG1: $script_arg1"
      echo "SCRIPT_ARG2: $script_arg2"
      echo "SCRIPT_ARG3: $script_arg3"

      echo "SCRIPT_CONTENT------------------------------------------------------------------------"
      [[ -n "$script_url" ]] && curl -sL $script_url
      echo "--------------------------------------------------------------------------------------"   
      [[ -n "$script_url" ]] && curl -sL $script_url | bash -s $script_arg1 $script_arg2 $script_arg3   
    '';
    wantedBy = [ "multi-user.target" ];
  };

  system.build.kexec = pkgs.runCommand "buildkexec" { } ''
    mkdir -p $out
    ln -s ${config.system.build.kernel}/${kernelTarget}  $out/${kernelName}
    ln -s ${config.system.build.netbootRamdisk}/initrd  $out/${initrdName}
    ln -s ${kexecScript}  $out/${kexecScriptName}
  '';
}
