{ exec, ... }: {
  asecret = args: exec ([ "asecret" ] ++ args);
}
