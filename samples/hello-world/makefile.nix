with import <nixpkgs> {};
let
  nix-make = callPackage ../../. {};

  inherit (nix-make.utils) cp;
  inherit (nix-make.utils.stdenv) run;
in
nix-make.make {
  root = ./.;

  rules = {
    "hello" = { dep, ... }: run ''
      gcc ${dep "hello.o"} -o $out
    '';

    "hello.o" = { dep, ... }: run ''
      gcc -c ${dep "hello.c"} -o $out
    '';

    "hello.c" = cp ./hello.c;
  };
}