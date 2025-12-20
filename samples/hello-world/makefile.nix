with import <nixpkgs> {};
let
  innix = callPackage ../../. {};

  inherit (innix.utils) cp;
  inherit (innix.utils.stdenv) run;
in
innix.make {
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