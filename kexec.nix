# https://github.com/NickCao/netboot/blob/master/flake.nix
# 1. pattern matching with the double brackets [source: https://www.baeldung.com/linux/bash-single-vs-double-brackets]
# 2. Parameter Expansion  [source: man bash]

{ pkgs, lib, config, modulesPath, ... }:
let
  kernelTarget = pkgs.stdenv.hostPlatform.linux-kernel.target;
  arch = pkgs.stdenv.hostPlatform.uname.processor;  #https://github.com/NixOS/nixpkgs/blob/93de6bf9ed923bf2d0991db61c2fd127f6e984ae/lib/systems/default.nix#L103
  kernelName = "${kernelTarget}-${arch}";
  initrdName = "initrd-${arch}";
  kexecScriptName = "kexec-${arch}";
  kexec-musl-bin = "kexec-musl-${arch}";
  wget-musl-bin = "wget-musl-${arch}";

  kexecScript = pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash
    set -e   

    echo "Downloading wget-musl" && curl -L -O https://github.com/mlyxshi/kexec/releases/download/latest/${wget-musl-bin}
    echo "Downloading kexec-musl" && curl -L -O https://github.com/mlyxshi/kexec/releases/download/latest/${kexec-musl-bin}
    chmod +x ./${wget-musl-bin}
    chmod +x ./${kexec-musl-bin}
    ./${wget-musl-bin} -q --show-progress -N https://github.com/mlyxshi/kexec/releases/download/latest/${initrdName}
    ./${wget-musl-bin} -q --show-progress -N https://github.com/mlyxshi/kexec/releases/download/latest/${kernelName}

    for arg in "$@"; do cmdScript+="$arg "; done
  
    [[ -f /etc/ssh/ssh_host_ed25519_key ]] && host_key=$(cat /etc/ssh/ssh_host_ed25519_key|base64|tr -d '\n') && host_key_pub=$(cat /etc/ssh/ssh_host_ed25519_key.pub|base64|tr -d '\n')
    
    for i in /home/$SUDO_USER/.ssh/authorized_keys /root/.ssh/authorized_keys /etc/ssh/authorized_keys.d/root; do
      if [[ -e $i && -s $i ]]; then 
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

    # aarch64 default kernel parameter size: 2048 bytes [https://github.com/torvalds/linux/blob/b7b275e60bcd5f89771e865a8239325f86d9927d/arch/arm64/include/uapi/asm/setup.h#L25]
    # x86_64  default kernel parameter size: 2048 bytes [https://github.com/torvalds/linux/blob/b7b275e60bcd5f89771e865a8239325f86d9927d/arch/x86/include/asm/setup.h#L7]
    # 2048 bytes is enough for most cases, but you still need to be careful about autorun script parameter size
    # authorized_keys:[rsa 4096 public key(840 bytes in base64 format) OR ed25519 public key(140 bytes in base64 format)]
    # ssh_host_ed25519_key:[ed25519 private key(560 bytes in base64 format)]
    # ssh_host_ed25519_key.pub:[ed25519 public key(140 bytes in base64 format)]
   
    kernel_param="init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} ''${sshkey:+sshkey=''$sshkey} ''${host_key:+host_key=''$host_key} ''${host_key_pub:+host_key_pub=''$host_key_pub} $cmdScript"
    kernel_param_size=''${#kernel_param}
    [[ $kernel_param_size -gt 2048 ]] && echo "Error: kernel parameter size: $kernel_param_size > 2048, use ed25519 authorized_keys instead" && exit 1

    echo "Wait..."
    echo "After SSH connection lost, ssh root@ip and enjoy NixOS!"
    ./${kexec-musl-bin} --kexec-syscall-auto --load ./${kernelName} --initrd=./${initrdName}  --command-line "$kernel_param"
    ./${kexec-musl-bin} -e
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

  zramSwap.enable = true;
  # Add swap (3xRAM), Max to 3G <-- Required for evaluation flake config, otherwise, VPS with 1G RAM will OOM
  zramSwap.memoryMax= 3 * 1024 * 1024 * 1024;
  zramSwap.memoryPercent = 300; 

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
        [[ $opt = script_arg4=* ]] && script_arg4="''${opt#script_arg4=}" && continue 
      done

      echo "SCRIPT_URL: $script_url"
      echo "SCRIPT_ARG1: $script_arg1"
      echo "SCRIPT_ARG2: $script_arg2"
      echo "SCRIPT_ARG3: $script_arg3"
      echo "SCRIPT_ARG4: $script_arg4"

      echo "SCRIPT_CONTENT------------------------------------------------------------------------"
      [[ -n "$script_url" ]] && curl -sL $script_url
      echo "--------------------------------------------------------------------------------------"   
      [[ -n "$script_url" ]] && curl -sL $script_url | bash -s $script_arg1 $script_arg2 $script_arg3 $script_arg4 
    '';
    wantedBy = [ "multi-user.target" ];
  };

  system.build.kexec = pkgs.runCommand "buildkexec" { } ''
    mkdir -p $out
    ln -s ${config.system.build.kernel}/${kernelTarget}  $out/${kernelName}
    ln -s ${config.system.build.netbootRamdisk}/initrd  $out/${initrdName}
    ln -s ${kexecScript}  $out/${kexecScriptName}
    ln -s ${pkgs.pkgsStatic.kexec-tools}/bin/kexec    $out/${kexec-musl-bin}
    ln -s ${pkgs.pkgsStatic.wget}/bin/wget    $out/${wget-musl-bin}
  '';
}
