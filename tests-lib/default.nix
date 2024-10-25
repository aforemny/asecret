{ pkgs ? import sources.nixpkgs { }
, sources ? import ./nix/sources.nix
}:
let
  inherit (pkgs) lib;
  src = lib.cleanSource ./..;
in
{
  makeTest = name: testConfig: testScript:
    let
      configFile = pkgs.writeText "configuration.nix" ''
        { lib, modulesPath, pkgs, ... }:
        let asecret-lib = import ${src}/lib; in
        {
          imports = [
            ${./hardware-configuration.nix}
            "''${modulesPath}/testing/test-instrumentation.nix"
          ];
          boot.loader.grub.device = "/dev/vda";
          documentation.enable = false;

          nix.extraOptions = '''
            plugin-files = ''${pkgs.nix-plugins}/lib/nix/plugins
            extra-builtins-file = ${src}/extra-builtins.nix
          ''';

          nixpkgs.overlays = [ (import "${src}/pkgs") ];
          environment.systemPackages = [
            pkgs.asecret
            pkgs.gnupg
            pkgs.pass
          ];

          ${testConfig}
        }
      '';
    in
    (import "${sources.nixpkgs}/nixos/lib" { }).runTest {
      inherit name;
      hostPkgs = pkgs;
      nodes = {
        machine = { lib, modulesPath, pkgs, ... }: {
          nix.settings.substituters = lib.mkForce [ ];
          nix.settings.hashed-mirrors = null;
          nix.settings.connect-timeout = 1;

          virtualisation.cores = 16; # 2;
          virtualisation.memorySize = 32 * 1024; # 2048;

          nix.extraOptions = ''
            plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
            extra-builtins-file = ${src}/extra-builtins.nix
          '';

          nixpkgs.overlays = [ (import "${src}/pkgs") ];
          environment.systemPackages = [
            pkgs.asecret
            pkgs.gnupg
            pkgs.pass
          ];

          system.extraDependencies = [
            (import "${sources.nixpkgs}/nixos" {
              configuration = "${configFile}";
            }).system
          ];
        };
      };
      testScript = ''
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("gpg --batch --pinentry-mode loopback --passphrase ''' --quick-generate-key 'Password Storage Key'")
        machine.succeed("PASSWORD_STORE_DIR=$PWD/secrets pass init 'Password Storage Key'")
        drvPath = machine.succeed("PASSWORD_STORE_DIR=$PWD/secrets NIX_PATH= nix-instantiate ${sources.nixpkgs}/nixos -I nixos-config=${configFile} -A system").strip()
        outPath = machine.succeed("nix-build " + drvPath).strip()
        machine.succeed("PASSWORD_STORE_DIR=$PWD/secrets asecret export")
        machine.succeed("nix-env --profile /nix/var/nix/profiles/system --set " + outPath)
        machine.succeed(outPath + "/bin/switch-to-configuration test")

        ${testScript}
      '';
    };

}
