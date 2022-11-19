{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }: {

    nixosConfigurations = {
      "kexec-x86_64" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./kexec.nix
        ];
      };

      "kexec-aarch64" = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./kexec.nix
        ];
      };
    };
  };

}
