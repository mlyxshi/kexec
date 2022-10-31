{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs ={ nixpkgs, ...}:{
    nixosConfigurations = {
      "kexec" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./kexec.nix
        ];
      };
    }; 
  }; 

}
