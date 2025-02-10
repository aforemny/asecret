{ pkgs ? import sources.nixpkgs { }
, sources ? import ./nix/sources.nix
}:
let
  tests-lib = import ./tests-lib { inherit pkgs sources; };
in
{
  hashed-password = tests-lib.makeTest "hashed-password"
    ''
      users.users.alice.isNormalUser = true;
      users.users.alice.hashedPasswordFile = asecret-lib.hashedPassword "alice/password";
    ''
    ''
      hashedPassword = machine.succeed("cat /var/src/secrets/alice/password").strip()
      machine.succeed("cat /etc/shadow | grep '^alice:" + hashedPassword + ":1::::::$'")
    '';
  password = tests-lib.makeTest "password"
    ''
      users.users.alice.isNormalUser = true;
      users.users.alice.passwordFile = asecret-lib.password "alice/password";
    ''
    ''
      hashedPassword = machine.succeed("cat /var/src/secrets/alice/password").strip()
      machine.succeed("cat /etc/shadow | grep '^alice:" + hashedPassword + ":1::::::$'")
    '';
  ssh-key-pair = tests-lib.makeTest "ssh-key-pair"
    ''
      services.openssh.enable = true;

      #users.users.root.openssh.authorizedKeys.keyFiles = [
      #  "''${(asecret-lib.sshKeyPair "root/id_ed25519"}.publicKeyFile"
      #];

      system.activationScripts."authorizedKeys-root".text = '''
        mkdir -p "/etc/ssh/authorized_keys.d";
        cp "''${(asecret-lib.sshKeyPair "root/id_ed25519").publicKeyFile}" "/etc/ssh/authorized_keys.d/root";
        chmod +r "/etc/ssh/authorized_keys.d/root"
      ''';
    ''
    ''
      print(machine.succeed("ssh -o StrictHostKeyChecking=no -i /var/src/secrets/root/id_ed25519 root@localhost :"))
    '';
  ssl-certificate = tests-lib.makeTest "ssl-certificate"
    ''
      services.nginx.enable = true;
      services.nginx.virtualHosts."bar.local".addSSL = true;
      services.nginx.virtualHosts."bar.local".sslCertificateKey = "/run/credentials/nginx.service/sslCertificateKey-bar";
      services.nginx.virtualHosts."bar.local".sslCertificate = "/run/credentials/nginx.service/sslCertificate-bar";
      services.nginx.virtualHosts."foo.local".addSSL = true;
      services.nginx.virtualHosts."foo.local".sslCertificateKey = "/run/credentials/nginx.service/sslCertificateKey-foo";
      services.nginx.virtualHosts."foo.local".sslCertificate = "/run/credentials/nginx.service/sslCertificate-foo";
      networking.hosts."127.0.0.1" = [ "bar.local" "foo.local" ];
      systemd.services.nginx.serviceConfig.LoadCredential = [
        "sslCertificate-bar:''${(asecret-lib.sslCertificate "ca/local" "ca/local/bar" [ "bar.local" "www.bar.local" ]).certificateFile}"
        "sslCertificate-foo:''${(asecret-lib.sslCertificate "ca/local" "ca/local/foo" [ "foo.local" "www.foo.local" ]).certificateFile}"
        "sslCertificateKey-bar:''${(asecret-lib.sslCertificate "ca/local" "ca/local/bar" [ "bar.local" "www.bar.local" ]).certificateKeyFile}"
        "sslCertificateKey-foo:''${(asecret-lib.sslCertificate "ca/local" "ca/local/foo" [ "foo.local" "www.foo.local" ]).certificateKeyFile}"
      ];
    ''
    ''
      print(machine.execute("curl -k -v https://foo.local --output /dev/null  2>&1"));
    '';
}
