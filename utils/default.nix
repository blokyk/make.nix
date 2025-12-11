{ callPackage }: {
  stdenv = callPackage ./stdenv.nix {};

  # Easily define one target as an alias to another target
  # :: TargetDef -> TargetDef
  #mkAlias = nix-make.utils.mkAlias;

  # Pretty much make's "phony targets": it always executes,
  # no matter the state of the dependencies
  # :: Recipe -> ???
  #mkAction = "todo";
}