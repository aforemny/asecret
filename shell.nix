{ pkgs ? import sources.nixpkgs { }
, sources ? import ./nix/sources.nix
}:
let inherit (pkgs) lib; in
pkgs.mkShell {
  buildInputs = [
    pkgs.docopts
    pkgs.findutils
    pkgs.jq
    pkgs.mdp
    pkgs.mkcert
    pkgs.mkpasswd
    pkgs.openssh
    pkgs.pass
    pkgs.pwgen
    pkgs.rsync
    (pkgs.writers.writeDashBin "asecret" ''
      set -efu
      export PATH=${lib.makeBinPath [
        pkgs.docopts
        pkgs.findutils
        pkgs.jq
        pkgs.mkcert
        pkgs.mkpasswd
        pkgs.openssh
        pkgs.pass
        pkgs.pwgen
        pkgs.rsync
      ]}:$PATH
      exec bash ${toString ./src}/asecret.sh "$@"
    '')
  ];
  shellHook = ''
    PASSWORD_STORE_DIR=${lib.escapeShellArg (toString ./.)}/secrets; export PASSWORD_STORE_DIR
  '';
}
