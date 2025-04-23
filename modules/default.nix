{ pkgs, lib, ... }:
{
  nixpkgs.overlays = [
    (import ../pkgs)
    (_: super: { asecret-lib = import ../lib { inherit lib; }; })
  ];
  environment.systemPackages = [ pkgs.asecret ];
}
