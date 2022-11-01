# https://github.com/NickCao/netboot/blob/master/flake.nix
# 1. pattern matching with the double brackets [source:https://www.baeldung.com/linux/bash-single-vs-double-brackets]
# 2. Parameter Expansion  [source:man bash]
# 3. IFS=$'\n'  make newlines the only separator [https://unix.stackexchange.com/questions/7011/how-to-loop-over-the-lines-of-a-file]

{ pkgs, lib, config, modulesPath, ... }: {
  
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix") # Most QEMU VPS, like Oracle
    (modulesPath + "/installer/netboot/netboot.nix")
  ];

  system.stateVersion = "22.11";

  boot = {
    initrd.kernelModules = [ "hv_storvsc" ]; # Important for Azure(Hyper-v)
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [ "btrfs" ];
  };

  networking.useNetworkd = true;
  networking.firewall.enable = false;
  services.getty.autologinUser = "root";

  services.openssh.enable = true;
  services.openssh.authorizedKeysFiles = [ "/run/authorized_keys" ];
  # Try overwrite /run/ssh_host_ed25519_key and /run/ssh_host_ed25519_key.pub to the original one, so we don't need "ssh-keygen -R IP"
  services.openssh.hostKeys = [{
    path = "/run/ssh_host_ed25519_key";
    type = "ed25519";
  }];

  # https://github.com/NixOS/nixpkgs/blob/26eb67abc9a7370a51fcb86ece18eaf19ae9207f/nixos/modules/services/networking/ssh/sshd.nix#L435
  systemd.services.sshd.preStart = lib.mkForce ''
    mkdir -m 0755 -p /etc/ssh

    export PATH=/run/current-system/sw/bin:$PATH

    IFS=$'\n'  

    for opt in $(xargs -n1 -a /proc/cmdline);
    do
      [[ $opt = sshkey=* ]] && sshkey="''${opt#sshkey=}"         
      [[ $opt = host_key=* ]] && host_key="''${opt#host_key=}"       
      [[ $opt = host_key_pub=* ]] && host_key_pub="''${opt#host_key_pub=}"
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
    wantedBy = [ "multi-user.target" ];
    script = ''
      export PATH=/run/current-system/sw/bin:$PATH

      IFS=$'\n'

      for opt in $(xargs -n1 -a /proc/cmdline);
      do
        [[ $opt = script_url=* ]] && script_url="''${opt#script_url=}"
        [[ $opt = script_arg1=* ]] && script_arg1="''${opt#script_arg1=}"
        [[ $opt = script_arg2=* ]] && script_arg2="''${opt#script_arg2=}"
        [[ $opt = script_arg3=* ]] && script_arg3="''${opt#script_arg3=}"     
      done

      echo "SCRIPT_URL: $script_url"
      echo "SCRIPT_ARG1: $script_arg1"
      echo "SCRIPT_ARG2: $script_arg2"
      echo "SCRIPT_ARG3: $script_arg3"

      sleep 5 # wait dhcp network connection?

      echo "SCRIPT_CONTENT------------------------------------------------------------------------"
      [[ -n "$script_url" ]] && curl -sL $script_url
      echo "--------------------------------------------------------------------------------------"   
      [[ -n "$script_url" ]] && curl -sL $script_url | bash -s $script_arg1 $script_arg2 $script_arg3   
    '';
  };




  system.build.kexecScript = lib.mkForce (pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash
    
    echo "Support Debian/Ubuntu. For other distros, install wget kexec-tools manually"

    # delete old version
    [ -f "bzImage" ] && rm bzImage
    [ -f "initrd.gz" ] && rm initrd.gz

    apt install -y wget kexec-tools

    wget https://github.com/mlyxshi/kexec/releases/download/latest/initrd.gz
    wget https://github.com/mlyxshi/kexec/releases/download/latest/bzImage

    if ! kexec -v >/dev/null 2>&1; then
      echo "kexec not found: please install kexec-tools" 2>&1
      exit 1
    fi

  
    [[ -f /etc/ssh/ssh_host_ed25519_key ]] && host_key=$(cat /etc/ssh/ssh_host_ed25519_key|base64|tr -d \\n) && host_key_pub=$(cat /etc/ssh/ssh_host_ed25519_key.pub|base64|tr -d \\n)
    [[ -f /home/$SUDO_USER/.ssh/authorized_keys ]] && sshkey=$(cat /home/$SUDO_USER/.ssh/authorized_keys|base64|tr -d \\n)

    echo "sshkey_base64: $sshkey"
    echo "host_key_base64: $host_key"
    echo "host_key_pub_base64: $host_key_pub"

    kexec --load ./bzImage --initrd=./initrd.gz \
      --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} $@ ''${sshkey:+sshkey=''$sshkey}   ''${host_key:+host_key=''$host_key}  ''${host_key_pub:+host_key_pub=''$host_key_pub}"
    
    kexec -e
  '');


  environment.systemPackages = [
    pkgs.htop
    pkgs.tree
  ];
}
