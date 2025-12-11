{ ... }: {
  # Augments stdenv.mkDerivation with a few
  # niceties, like automatically calling "getTarget"
  # on any build input that isn't a derivation
  # :: Recipe -> TargetDef
  #mkRule = nix-make.utils.stdenv.mkRule;

  # Like `mkRule`, but allows defining
  # :: (PatternRecipe | ([captures] -> PatternRecipe)) -> TargetDef
  #    ^^^^^^^^^^^^ this is a functor btw ^^^^^^^^^^^^
  #mkPattern = nix-make.utils.stdenv.mkPattern;
}