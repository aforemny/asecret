%title: asecret - automatic secret provisioning
%author: aforemny
%date: 2024-10-29

-> asecret - automatic secret provisioning <-
=============================================

-> Nix User Group Hannover Braunschweig Wolfsburg <-
----------------------------------------------------

-> Hannover, 29.10.2024 <-
----------------------

-> Alexander Foremny <aforemny@posteo.de> <-
--------------------------------------------
---

# motivation

secrets: internally-consistent random values

## examples

-   ssh host keys
-   self-signed SSL certificates
-   VPN keys

---

# goal

-   simple tool
-   maximally transparent

## non-goals / compromises

-   secret *deployment*
-   advanced secret management
-   perfect security

---

# goals

## goal: simple tool

-   plain text files (encrypted)
-   no extra state

^

## goal: maximally transparent

-   one line of configuration per secret
-   usage counts, no extra lines!

---

# assumptions

-   secrets are stored locally (ie. git)
-   evaluation of system configuration generates secrets
-   deployment of unencrypted secrets prior to system activation
-   secrets are *runtime values*

---

# implementation

-   [nix plugin](github.com/shlevy/nix-plugins)
-   supports [password store](passwordstore.org)

## stats

```console
❯ cloc . --exclude-dir [..]
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Bourne Shell                     1             12              4             80
Nix                              2              0              0              9
-------------------------------------------------------------------------------
SUM:                             3             12              4             89
-------------------------------------------------------------------------------
```

---

# examples

-   user passwords
-   ssh keys
-   self-signed ssl certificates

---

# example: user passwords

## configuration

```nix
users.users.alice.isNormalUser = true;
users.users.alice.hashedPasswordFile = asecret-lib.hashedPassword "alice/password";
```

## generated password

``` console
❯ pass show alice/password
$y$j9T$pwv.GXtzjhyACkg4VWOoo.$cmUkETleggnRnz0Fn8QZVVpEa3RZSdN..eUqPj1sEK3
```

^

## update user password (not implemented)

```
❯ asecret insert hashed-password alice/password
Password: ***
```

---

# example: authorize ssh keys (incorrect)

## configuration

```nix
users.users.root.openssh.authorizedKeys.keyFiles = [
  ${(asecret-lib.sshKeyPair "root/id_ed25519").publicKeyFile} ];
```

reason: `keyFiles` reads "secret" file into Nix store at *build time*

---

# example: authorize ssh keys

## configuration

```nix
system.activationScripts."authorizedKeys-root".text = ''
  mkdir -p "/etc/ssh/authorized_keys.d";
  cp "${(asecret-lib.sshKeyPair "root/id_ed25519").publicKeyFile}" \\
    "/etc/ssh/authorized_keys.d/root";
  chmod +r "/etc/ssh/authorized_keys.d/root"
'';
```

## generated passwords

```
❯ pass show root/
root
├── id_ed25519
└── id_ed25519.pub
```

^

## use

```
❯ ssh -i /var/src/secrets/root/id_ed25519 root@localhost
^D
```

---

# example: self-signed SSL certificates

## configuration

```nix
services.nginx.virtualHosts."bar.local".addSSL = true;
services.nginx.virtualHosts."bar.local".sslCertificateKey = \\
  "/run/credentials/nginx.service/sslCertificateKey";
services.nginx.virtualHosts."bar.local".sslCertificate = \\
  "/run/credentials/nginx.service/sslCertificate";
systemd.services.nginx.serviceConfig.LoadCredential = [
  "sslCertificate:${(asecret-lib.sslCertificate "ca/local" "ca/local/bar" \\
    [ "bar.local" ]).certificateFile}"
  "sslCertificateKey:${(asecret-lib.sslCertificate "ca/local" "ca/local/bar" \\
    [ "bar.local" ]).certificateKeyFile}"
];
```

## generated passwords

```console
❯ pass show ca/local
ca/local
├── bar-key.pem
├── bar.pem
├── rootCA-key.pem
└── rootCA.pem
```

---

# example deployment

## 1. evaluate to generate secrets

```console
❯ drv=$(
  PASSWORD_STORE_DIR=$PWD/secrets \\
  NIXOS_CONFIG=$PWD/systems/a-host.nix \\
  nix-instantiate '<nixpkgs/nixos>' -A system
)
```

## 2. build system locally

```console
❯ out=$(nix-build "$drv")
```

## 3. transfer system

```console
❯ nix-copy-closure --to root@1.2.3.4 "$out"
```

## 4. transfer secrets

```console
❯ ASECRET_OUT=root@1.2.3.4:/var/src/secrets asecret export
```

(cont.)

---

# example deployment (cont.)

## 5. activate system

```console
❯ ssh root@1.2.3.4 "$(printf %q "$out"/activate)"
```

```console
❯ ssh root@1.2.3.4 "$(printf %q \\
  'nix-env --profile /nix/var/nix/profiles/system --set '"$out")"
```

---

# open questions

-   distinguish secret from public files
-   fine-grained deployment strategies

---

# open question: distinguish secret from public files

-   ie. private and public key-pairs
-   suggestion: place public keys into `ASECRET_PUBLIC=./public` folder
    -   this should work at build time!

---

# open question: fine-grained deployment strategies

-   currently `asecret export` exports *all* secrets
-   how can we export secrets, say, on a per-host basis?
-   suggestion:
    -   secret naming scheme, ie. `foo -> per-host/a-host/foo`
    -   `asecret export per-host/a-host`
-   *problem:* works for producers, how for consumers?
-   possible suggestion: symlink support for `pass`

## configuration (`a-host`)

```nix
asecret-lib.produce.hashedPassword "per-host/a-host/foo"
```

## configuration (`b-host`)

```nix
asecret-lib.consume.hashedPassword "per-host/b-host/foo" "per-host/a-host/foo"
```

```console
pass per-host/a-host
└── foo
pass per-host/b-host
└── foo (-> ../a-host/foo)
```

**note:** `pass` does not support symlinks like that.

---

# setup

(see [README.md](../README.md) in the future)

## configure system host

```nix
nix.extraOptions = ''
  plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
  extra-builtins-file = ${./asecret/extra-builtins.nix}
'';
nixpkgs.overlays = [ ./asecret/pkgs ];
environment.systemPackages = [ pkgs.asecret ];
```

## initialize a password store

```
export PASSWORD_STORE_DIR=$PWD/secrets
pass init 'Password Storage Key'
```

## import asecret-lib at call site

```nix
let asecret-lib = import ./asecret/lib; in ..
```
