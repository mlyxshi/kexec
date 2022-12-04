# Remove unnecessary packages and services in kexec environment
{ pkgs, lib, config, ... }: {
  security.sudo.enable = false;
  networking.firewall.enable = false;
  documentation.enable = false;
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/minimal.nix
  environment.noXlibs = true;
  programs.command-not-found.enable = false;
  xdg.autostart.enable = false;
  xdg.icons.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/system-path.nix
  environment.defaultPackages = lib.mkForce [];
  # remove nano https://github.com/NixOS/nixpkgs/blob/14ddeaebcbe9a25748221d1d7ecdf98e20e2325e/nixos/modules/programs/nano.nix#LL38C5-L38C32
  programs.nano.syntaxHighlight = false;
}
