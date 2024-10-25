# /!\ WORK-IN-PROGRESS, DO NOT USE! /!\
# asecret

asecret is a secret *provisioning* utility for Nix configuration.

## Motivation

Service configuration using Nix is a blast!: It is usually sufficient to enable a service, and evaluate your system configuration. Congratulations, you've successfully configured your service, without needing to have expert knowledge about it. Should the service require non-defaultable configuration, you get an error message at evaluation time that tells you what option to set. Usually, you can set those options without needing to have expert knowledge as well.

Not so with secrets! Suppose you are configuring a user account, and want to set `hashedPasswordFile`. You are wondering, how do I create a hashed password again? Suppose you are HTTPS-securing a set of web services in an intranet. How do I generate a PKI again? Suppose you are configuring a mail server. What is a DKIM-signature again? Answering these questions requires in-depth knowledge, and spoil the fun.

Would it not be great if you could just specify the type of a password, and have Nix generate it automatically for you?

Consider the example of generating a user password.

```nix
{
  users.users.alice.hashedPasswordFile = lib.secrets.hashedPassword "per-user/alice";
}
```

This would generate a secure, random password for user alice at evaluation time, and store it in a local secret store. If you later wanted to change it so something non-random, you can replace that password with `asecret insert per-user/alice`.

## Assumptions

We are assuming that passwords are generated prior to deploying a machine, on the machine that performs the deployment. This is in contrast to an alternative approach where secrets are generated on the target machine at runtime, and essentially treated as state.

The current implementation assumes that you are using a local password store ./secrets for storing secrets.

## Setup

You can easily create a Nix shell environment with the necessary prerequisites.

```nix
{ pkgs ? import <nixpkgs> { }
}: pkgs.mkShell {
  buildInputs = [
    pkgs.asecret
    pkgs.nix 
  ];
  shellHook = ''
    export NIX_CONFIG="
      plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
      extra-builtins-file = ${./.}/extra-builtins.nix
    "
  '';
}
```

## Usage

### Configuring secrets

TODO lib secrets

```
{
  users.users.alice.hashedPasswordFile = lib.secrets.hashedPassword "per-user/alice";
}
```

### Replacing randomly-generated secrets

Use astore insert to insert known secrets ahead of evaluation time, or to replace existing secrets.

```console
astore insert per-user/alice
```

### Rotating secrets

Because secrets are defined in the Nix configuration, for rotating all secrets it is sufficient to clear the password store ./secrets, and re-evaluate all systems.

## Limitations

asecret is a secret *provisioning* tool (ie. generating the secrets required for a system configuration), and does not concern itself with *deploying secrets* (ie. copying the relevant secrets to the target host).
