with import <nixpkgs> {};
let
  nix-make = callPackage ../../. {};

  inherit (nix-make.utils) autoSrc;
  inherit (nix-make.utils.stdenv) run;
in
nix-make.make {
  root = ./.;

  rules = {
    "hello" = { dep, ... }: run ''
      gcc ${dep "hello.o"} -o $out
    '';

    "%.o" = { dep, capture, ... }: run ''
      gcc -c ${dep "${capture}.c"} -o $out
    '';

    # C files are always source files
    "%.c" = autoSrc;
  };
}