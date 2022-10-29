{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
  };

  outputs ={ self, nixpkgs, ...}:
    let
      stateVersion = "22.05";
    in
    {
      nixosConfigurations = {
       # nix build .#nixosConfigurations.kexec.config.system.build.kexecTree
        "kexec" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./kexec.nix
            {
              system.stateVersion = stateVersion;
            }
          ];
        };
      }; 
    }; 
}
