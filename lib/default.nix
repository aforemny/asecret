let generate = args: builtins.fromJSON (builtins.extraBuiltins.asecret ([ "generate" ] ++ args)); in
{
  hashedPassword = secretPath: generate [ "hashed-password" secretPath ];
  sshKeyPair = secretPath: generate [ "ssh-key-pair" "--type" "ed25519" secretPath ];
  sslCertificate = caPath: certPath: domains: generate ([ "ssl-certificate" caPath certPath ] ++ domains);
}
