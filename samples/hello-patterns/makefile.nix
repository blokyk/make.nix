with import <nixpkgs> {};
let
  innix = callPackage ../../. {};

  inherit (innix.utils) autoSrc;
  inherit (innix.utils.stdenv) run;
in
innix.make {
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