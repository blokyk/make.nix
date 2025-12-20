{ callPackage, lib, pkgs }: rec {
  stdenv = callPackage ./stdenv.nix {};

  /**
    Runs a given command in a basic environment (`stdenvNoCC`).
    If you want to run inside `stdenv` (e.g. to use `gcc`), then
    use `innix.utils.stdenv.run` instead.

    Note 1: You need to create or write to `$out` (or at least `touch` it),
    or the command will be treated as having failed.

    Note 2: The derivation's name will be the name registered in the context;
    this is generally the target's name.

    # Inputs

    `cmd`
    : The command that should be ran.

    # Type

    ```
    run :: string -> rule
    ```

    # Examples
    :::{.example}
    ## `utils.run` usage example

    ```nix
    # This recipe will build a derivation (named 'foo') that simply creates a
    # file containing "Foo's content" in it.
    foo = run ''
      echo "Foo's content" > $out
    '';
    ```
  */
  run = cmd: { name, derivationArgs, ... }: pkgs.runCommand name derivationArgs cmd;

  runLocal = cmd: { name, derivationArgs, ... }: pkgs.runCommandLocal name derivationArgs cmd;

  cp = path: runLocal ''
    cp ${path} -r $out
  '';

  autoSrc = { root, name, ... }: runLocal ''
    cp "${root}/${name}" -r $out
  '';
}