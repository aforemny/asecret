{ lib, modulesPath, ... }:
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "floppy" "sr_mod" "virtio_blk" ];
  boot.kernelModules = [ "kvm-intel" ];
  fileSystems."/".device = "/dev/vda";
  fileSystems."/".fsType = "ext4";
  fileSystems."/nix/.ro-store".device = "nix-store";
  fileSystems."/nix/.ro-store".fsType = "9p";
  fileSystems."/nix/.rw-store".device = "tmpfs";
  fileSystems."/nix/.rw-store".fsType = "tmpfs";
  fileSystems."/tmp/shared".device = "shared";
  fileSystems."/tmp/shared".fsType = "9p";
  fileSystems."/tmp/xchg".device = "xchg";
  fileSystems."/tmp/xchg".fsType = "9p";
  fileSystems."/nix/store".device = "overlay";
  fileSystems."/nix/store".fsType = "overlay";
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
