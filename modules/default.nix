{ pkgs, lib, ... }:
{
  nix.extraOptions = ''
    plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
    extra-builtins-file = ${../extra-builtins.nix}
  '';
  nixpkgs.overlays = [
    (import ../pkgs)
    (_: super: { asecret-lib = import ../lib { inherit lib; }; })
  ];
  environment.systemPackages = [ pkgs.asecret ];
}
