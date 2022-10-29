# https://github.com/NickCao/netboot/blob/master/flake.nix
{ pkgs, modulesPath, ... }: {
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix") # Most VPS, like oracle
    (modulesPath + "/installer/netboot/netboot.nix")
  ];

  boot = {
    initrd.kernelModules = [ "hv_storvsc" ]; # important for azure(hyper-v)
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [ "btrfs" ];
  };

  networking.useNetworkd = true;
  networking.firewall.enable = false;

  services.openssh.enable = true;
  services.getty.autologinUser = "root";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpaY3LyCW4HHqbp4SA4tnA+1Bkgwrtro2s/DEsBcPDe"
  ];


  environment.systemPackages = [
    pkgs.htop
  ];
}
