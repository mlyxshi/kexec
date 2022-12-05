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
  boot.initrd.availableKernelModules = [ "squashfs" "overlay" ];
  boot.initrd.kernelModules = [ "loop" "overlay" ];
  boot.initrd.compressor = "zstd";


  # Create the squashfs image that contains the Nix store.
  system.build.squashfsStore = pkgs.stdenv.mkDerivation {
    name = "nix-store.squashfs";
    nativeBuildInputs = [ pkgs.squashfsTools ];
    buildCommand = ''
      closureInfo=${pkgs.closureInfo { rootPaths = config.system.build.toplevel; }}
      # Also include a manifest of the closures in a format suitable for nix-store --load-db.
      cp $closureInfo/registration nix-path-registration
      mksquashfs nix-path-registration $(cat $closureInfo/store-paths) $out -no-hardlinks -keep-as-directory -all-root -b 1M -comp zstd -Xcompression-level 19
    '';
  };


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


  # boot.postBootCommands = ''
  #   # After booting, register the contents of the Nix store in the Nix database in the tmpfs.
  #   ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration
  # '';
}

# References
# https://www.deepanseeralan.com/tech/some-notes-on-filesystems-part2/
