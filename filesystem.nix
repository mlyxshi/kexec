# This module creates netboot media containing the given NixOS
# configuration.

{ config, lib, pkgs, ... }: {

  # kexec don't need a bootloader
  boot.loader.grub.enable = false;

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

  boot.initrd.availableKernelModules = [ "squashfs" "overlay" ];

  boot.initrd.kernelModules = [ "loop" "overlay" ];


  # Create the squashfs image that contains the Nix store.
  system.build.squashfsStore = pkgs.callPackage ./make-squashfs.nix {
    storeContents = [ config.system.build.toplevel ];
  };


  # Create the initrd
  system.build.netbootRamdisk = pkgs.makeInitrdNG {
    inherit (config.boot.initrd) compressor;
    prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

    contents =
      [{
        object = config.system.build.squashfsStore;
        symlink = "/nix-store.squashfs";
      }];
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
