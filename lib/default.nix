{ lib, ... }:
let generate = args: builtins.fromJSON (builtins.extraBuiltins.asecret ([ "generate" ] ++ args)); in
{
  hashedPassword = secretPath: generate [ "hashed-password" secretPath ];
  password = secretPath: generate [ "password" secretPath ];
  sshKeyPair = secretPath: lib.makeOverridable
    ({ type }:
      generate [ "ssh-key-pair" "--type" type secretPath ])
    { type = "ed25519"; };
  sslCertificate = secretPath: domains: generate ([ "ssl-certificate" secretPath ] ++ domains);
  wireguard = secretPath: generate [ "wireguard" secretPath ];
}
