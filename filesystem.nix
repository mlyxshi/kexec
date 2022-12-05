# This module creates netboot media containing the given NixOS
# configuration.

{ config, lib, pkgs, ... }: {
  fileSystems."/" = {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  fileSystems."/nix/.ro-store" = {
    fsType = "squashfs";
    device = "../nix-store.squashfs";
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

  # kexec don't need a bootloader
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
      mksquashfs nix-path-registration $(cat $closureInfo/store-paths) $out \
        -no-hardlinks -keep-as-directory -all-root -b 1M -comp zstd -Xcompression-level 19
    '';
  };


  # Create the initrd
  system.build.netbootRamdisk = pkgs.makeInitrdNG {
    # config.system.build.initialRamdisk is compressed with zstd
    # config.system.build.squashfsStore is compressed with zstd
    compressor = "cat";
    prepend = [ "${config.system.build.initialRamdisk}/initrd.zst" ];

    contents = [
      {
        object = config.system.build.squashfsStore;
        symlink = "/nix-store.squashfs";
      }
    ];
  };



  boot.postBootCommands =
    ''
      # After booting, register the contents of the Nix store
      # in the Nix database in the tmpfs.
      ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration

      # nixos-rebuild also requires a "system" profile and an
      # /etc/NIXOS tag.
      touch /etc/NIXOS
      ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    '';



}

# References
# https://www.deepanseeralan.com/tech/some-notes-on-filesystems-part2/
