with import <nixpkgs> {};
let
  nix-make = callPackage ../../. {};

  inherit (nix-make.utils.stdenv) run;
in
nix-make.makeConfig {
  root = ./.;

  rules = {
    "hello" = { dep, ... }: run ''
      gcc ${dep "hello.o"} -o $out
    '';

    "hello.o" = { dep, ... }: run ''
      gcc -c ${dep "hello.c"} -o $out
    '';

    # "%.o" = { dep, capture, ... }: run ''
    #   gcc -c ${dep "${capture}.o"} -o $out
    # '';
  };
}