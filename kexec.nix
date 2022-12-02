{ pkgs, lib, config, modulesPath, ... }:
let
  kernelTarget = pkgs.hostPlatform.linux-kernel.target;
  arch = pkgs.hostPlatform.uname.processor;  #https://github.com/NixOS/nixpkgs/blob/93de6bf9ed923bf2d0991db61c2fd127f6e984ae/lib/systems/default.nix#L103
  kernelName = "${kernelTarget}-${arch}";
  initrdName = "initrd-${arch}";
  kexecScriptName = "kexec-${arch}";
  kexec-musl-bin = "kexec-musl-${arch}";
  wget-musl-bin = "wget-musl-${arch}";

  kexecScript = pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash
    set -e   

    curl -L -O https://github.com/mlyxshi/kexec/releases/download/latest/${wget-musl-bin} && chmod +x ./${wget-musl-bin} 
    # -N only download the file if it has changed
    ./${wget-musl-bin} -q --show-progress -N https://github.com/mlyxshi/kexec/releases/download/latest/${kexec-musl-bin} && chmod +x ./${kexec-musl-bin}
    ./${wget-musl-bin} -q --show-progress -N https://github.com/mlyxshi/kexec/releases/download/latest/${initrdName}
    ./${wget-musl-bin} -q --show-progress -N https://github.com/mlyxshi/kexec/releases/download/latest/${kernelName}

    for arg in "$@"
    do
      # script_args escape double quotes manually
      [[ $arg = script_args=* ]] && arg="script_args=\"''${arg#script_args=}\""   
      cmdScript+="$arg "
    done

  
    INITRD_TMP=$(mktemp -d --tmpdir=.)
    cd "$INITRD_TMP" 
    mkdir -p initrd/ssh && cd initrd
    for i in /home/$SUDO_USER/.ssh/authorized_keys /root/.ssh/authorized_keys /etc/ssh/authorized_keys.d/root; do
      if [[ -e $i && -s $i ]]; then 
        echo "--------------------------------------------------"
        echo "Get SSH key from: $i"
        cat $i >> ssh/authorized_keys
      fi     
    done

    for i in /etc/ssh/ssh_host_*; do cp $i ssh; done

    find | cpio -o -H newc --quiet | gzip -9 > ../extra.gz
    cd .. && cat extra.gz >> ../${initrdName}
    cd .. && rm -r "$INITRD_TMP"

    echo "--------------------------------------------------"
    echo "Script Info: $@"
    echo "--------------------------------------------------"
    echo "Wait..."
    echo "After SSH connection lost, ssh root@ip and enjoy NixOS!"
    ./${kexec-musl-bin} --kexec-syscall-auto --load ./${kernelName} --initrd=./${initrdName}  --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} $cmdScript"
    ./${kexec-musl-bin} -e
  '';
in
{

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix") # Most QEMU VPS, like Oracle
    (modulesPath + "/installer/netboot/netboot.nix")
  ];

  system.stateVersion = "23.05";

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
  '';


  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.initrd.kernelModules = [ "hv_storvsc" ]; # Important for Azure(Hyper-v)
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = [ "btrfs" ];

  boot.kernel.sysctl."vm.swappiness" = 100;
  zramSwap.enable = true; # Enable zram, otherwise machine below 1GB RAM will OOM when evaluating nix flake config
  zramSwap.memoryPercent = 200;
  zramSwap.memoryMax= 2 * 1024 * 1024 * 1024;

  networking.useNetworkd = true;
  networking.firewall.enable = false;
  systemd.network.wait-online.anyInterface = true;
  services.getty.autologinUser = "root";
  services.openssh.enable = true;

  boot.initrd.postMountCommands = ''
    mkdir -m 700 -p /mnt-root/root/.ssh
    mkdir -m 755 -p /mnt-root/etc/ssh
    install -m 400 ssh/authorized_keys /mnt-root/root/.ssh
    install -m 400 ssh/ssh_host_* /mnt-root/etc/ssh
  '';

  systemd.services.process-cmdline-script = {
    after = [ "network-online.target" ];
    script = ''
      export PATH=/run/current-system/sw/bin:$PATH
      IFS=$'\n' #for loop split by newline, otherwise it will split by space

      for opt in $(xargs -n1 -a /proc/cmdline)
      do
        [[ $opt = script_url=* ]] && script_url="''${opt#script_url=}" && continue
        [[ $opt = script_args=* ]] && script_args="''${opt#script_args=}" && continue
      done

      echo "SCRIPT_URL: $script_url"
      echo "SCRIPT_ARGS: $script_args"  
      [[ -n "$script_url" ]] && curl -sL $script_url | bash -s $script_args
    '';
    wantedBy = [ "multi-user.target" ];
  };

  system.build.kexec = pkgs.runCommand "buildkexec" { } ''
    mkdir -p $out
    ln -s ${config.system.build.kernel}/${kernelTarget} $out/${kernelName}
    ln -s ${config.system.build.netbootRamdisk}/initrd  $out/${initrdName}
    ln -s ${kexecScript}                                $out/${kexecScriptName}
    ln -s ${pkgs.pkgsStatic.kexec-tools}/bin/kexec      $out/${kexec-musl-bin}
    ln -s ${pkgs.pkgsStatic.wget}/bin/wget              $out/${wget-musl-bin}
  '';
}
