let
  qemuKernelModules = [ "virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "virtio_balloon" "virtio_console" ];
  hypervKernelModules = [ "hv_storvsc" ];
  commonKernelModules = [ "nvme" "ahci" ];
  # add extra kernel modules: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/all-hardware.nix
  KernelModules = qemuKernelModules ++ hypervKernelModules ++ commonKernelModules;
in
{
  boot.initrd.availableKernelModules = KernelModules;
  # remove default kernel modules: https://github.com/NixOS/nixpkgs/blob/660e7737851506374da39c0fa550c202c824a17c/nixos/modules/system/boot/kernel.nix#L214
  boot.initrd.includeDefaultModules = false;
}
