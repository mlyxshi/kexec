{ pkgs, lib, config, modulesPath, ... }:
let
  kernelTarget = pkgs.hostPlatform.linux-kernel.target;
  arch = pkgs.hostPlatform.uname.processor; #https://github.com/NixOS/nixpkgs/blob/93de6bf9ed923bf2d0991db61c2fd127f6e984ae/lib/systems/default.nix#L103
  kernelName = "${kernelTarget}-${arch}";
  initrdName = "initrd-${arch}.zst";
  kexecScriptName = "kexec-${arch}";
  kexec-musl-bin = "kexec-musl-${arch}";

  kexecScript = pkgs.writeScript "kexec-boot" ''
    #!/usr/bin/env bash
    set -e   

    echo "Downloading kexec-musl-bin" && curl -LO https://github.com/mlyxshi/kexec/releases/download/latest/${kexec-musl-bin} && chmod +x ./${kexec-musl-bin}
    echo "Downloading initrd" && curl -LO https://github.com/mlyxshi/kexec/releases/download/latest/${initrdName}
    echo "Downloading kernel" && curl -LO https://github.com/mlyxshi/kexec/releases/download/latest/${kernelName}
 
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
   
    [[ -n "$1" ]] && echo "--------------------------------------------------" && echo "Downloading AutoRun Script" && curl -Lo autorun.sh "$1"
    for arg in "''${@:2}"; do echo $arg >> autorunParameters; done      # begin at the second argument
  
    find | cpio -o -H newc --quiet | gzip -9 > ../extra.gz
    cd .. && cat extra.gz >> ../${initrdName}
    cd .. && rm -r "$INITRD_TMP"

    echo "--------------------------------------------------"
    echo "Wait..."
    echo "After SSH connection lost, ssh root@ip and enjoy NixOS!"
    ./${kexec-musl-bin} --kexec-syscall-auto --load ./${kernelName} --initrd=./${initrdName}  --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"
    ./${kexec-musl-bin} -e
  '';
in
{

  imports = [
    ./fileSystem.nix
    ./strip.nix
    ./kernelModule.nix
  ];

  system.stateVersion = lib.trivial.release;

  environment.systemPackages = with pkgs; [
    htop
    lf # Terminal File Browser
    neovim-unwrapped
    nix-tree
    parted
  ];

  environment.sessionVariables.EDITOR = "nvim";
  environment.etc."lf/lfrc".text = ''
    set hidden true
    set number true
    set drawbox true
    set dircounts true
    set incsearch true
    set period 1
    map Q   quit
    map D   delete
    cmd open ''${{ $EDITOR "$f"}}
  '';
  environment.etc."xdg/nvim/sysinit.vim".text = ''
    lua <<EOF
    vim.keymap.set("n", "Q", ":qa<CR>")
    vim.keymap.set("n", "ZQ", ":qa!<CR>")
    vim.keymap.set("n", "ZZ", ":wa|:qa<CR>")
    vim.opt.cmdheight = 0
    EOF
  '';
  environment.shellAliases = {
    r = "lf"; # like ranger 
    v = "nvim";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = [ "btrfs" ];

  boot.kernel.sysctl."vm.swappiness" = 100;
  zramSwap.enable = true; # Enable zram, otherwise machine below 1GB RAM will OOM when evaluating nix flake config
  zramSwap.memoryPercent = 200;
  zramSwap.memoryMax = 2 * 1024 * 1024 * 1024;

  networking.useNetworkd = true;
  systemd.network.wait-online.anyInterface = true;
  services.getty.autologinUser = "root";
  services.openssh.enable = true;

  boot.initrd.postMountCommands = ''
    mkdir -m 700 -p /mnt-root/root/.ssh
    mkdir -m 755 -p /mnt-root/etc/ssh
    install -m 400 ssh/authorized_keys /mnt-root/root/.ssh
    install -m 400 ssh/ssh_host_* /mnt-root/etc/ssh

    [[ -f autorun.sh ]] && install -m 700 autorun.sh /mnt-root/etc
    [[ -f autorunParameters ]] && install -m 700 autorunParameters /mnt-root/etc
  '';

  systemd.services.autorun-script = {
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/etc/autorun.sh";
    script = ''
      export PATH=/run/current-system/sw/bin:$PATH
      if [[ -f /etc/autorunParameters ]]; then
        mapfile args < /etc/autorunParameters
        bash /etc/autorun.sh ''${args[@]}
      else
        bash /etc/autorun.sh
      fi  
    '';
    wantedBy = [ "multi-user.target" ];
  };

  system.build.kexec = pkgs.runCommand "buildkexec" { } ''
    mkdir -p $out
    ln -s ${config.system.build.kernel}/${kernelTarget}         $out/${kernelName}
    ln -s ${config.system.build.netbootRamdisk}/initrd.zst      $out/${initrdName}
    ln -s ${kexecScript}                                        $out/${kexecScriptName}
    ln -s ${pkgs.pkgsStatic.kexec-tools}/bin/kexec              $out/${kexec-musl-bin}
  '';
}



# Reference: 
# initrd
# https://github.com/nix-community/nixos-images/blob/main/nix/kexec-installer/module.nix
# https://unix.stackexchange.com/questions/163346/why-is-it-that-my-initrd-only-has-one-directory-namely-kernel
# https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/system/boot/stage-1-init.sh
# https://landley.net/writing/rootfs-intro.html
# https://landley.net/writing/rootfs-howto.html
# https://landley.net/writing/rootfs-programming.html
