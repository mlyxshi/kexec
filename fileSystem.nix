# https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/netboot/netboot.nix
{ config, lib, pkgs, ... }: {
  fileSystems."/" = {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  fileSystems."/nix/.ro-store" = {
    fsType = "squashfs";
    # Be cafeful about the device path: https://github.com/NixOS/nixpkgs/blob/bc85ef815830014d9deabb0803d46a78c832f944/nixos/modules/system/boot/stage-1-init.sh#L520-L540
    device = "nix-store.squashfs";
    options = [ "loop" ];
    neededForBoot = true;
  };

  fileSystems."/nix/.rw-store" = {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
    neededForBoot = true;
  };

  fileSystems."/nix/store" = {
    fsType = "overlay";
    device = "overlay";
    options = [
      "lowerdir=/nix/.ro-store"
      "upperdir=/nix/.rw-store/store"
      "workdir=/nix/.rw-store/work"
    ];

    depends = [
      "/nix/.ro-store"
      "/nix/.rw-store/store"
      "/nix/.rw-store/work"
    ];
  };

  # kexec don't need bootloader
  boot.loader.grub.enable = false;
  boot.initrd.kernelModules = [ "squashfs" "overlay" "loop" ];
  boot.initrd.compressor = "zstd";


  # Create the squashfs image: System Closure Nix Store.
  system.build.squashfsStore = pkgs.runCommand "nix-store.squashfs" { } ''
    closurePaths=${pkgs.closureInfo { rootPaths = config.system.build.toplevel; }}/store-paths
    ${pkgs.squashfsTools}/bin/mksquashfs $(cat $closurePaths) $out -no-hardlinks -keep-as-directory -all-root -b 1M -comp zstd -Xcompression-level 19
  '';

  # Create the netbootRamdisk
  system.build.netbootRamdisk = pkgs.makeInitrdNG {
    compressor = "zstd";
    prepend = [ "${config.system.build.initialRamdisk}/initrd.zst" ];
    contents = [
      {
        object = config.system.build.squashfsStore;
        symlink = "/nix-store.squashfs";
      }
    ];
  };

}

# References
# https://www.deepanseeralan.com/tech/some-notes-on-filesystems-part2/
# https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/kernel/make-initrd-ng.nix

# wget https://github.com/mlyxshi/kexec/releases/download/latest/initrd-x86_64.zst
# zstd -d initrd-x86_64.zst
# binwalk initrd-x86_64
# ASCII CPIO archives consist of multiple entries, ending with an entry named 'TRAILER'.
# (cpio -idv; cpio -idv) < initrd-x86_64
