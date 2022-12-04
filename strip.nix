# Remove unnecessary packages and services in kexec environment
{ pkgs, lib, config, ... }: {
  security.sudo.enable = false;
  networking.firewall.enable = false;
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/minimal.nix
  environment.noXlibs = true;
  programs.command-not-found.enable = false;
  xdg.autostart.enable = false;
  xdg.icons.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/system-path.nix
  environment.defaultPackages = lib.mkForce [];
}
