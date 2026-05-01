let
  # This is a placeholder default key.
  # Get your actual root pub key via: cat /etc/ssh/ssh_host_ed25519_key.pub
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzdcY0w+18146cN/pBejk+2H5MifrHFvDbNyYPXIgIf root@NixPC";
in
{
  "syncthing-cert.age".publicKeys = [ root ];
  "syncthing-key.age".publicKeys = [ root ];
}
