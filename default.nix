{ callPackage }: {
  utils = callPackage ./utils {};

  # TargetDef = Derivation | (Derivation // %output of mkTarget%)
  #
  # Recipe = [args to stdenv.mkDerivation] // {
  #   # All derivations and targets that are needed tp
  #   # build this. Targets can be referenced either directly
  #   # with their value, or indirectly via their name.
  #   nativeBuildInputs, buildInputs :: [TargetDef | str]
  #     = []
  #
  #   # The command(s) to execute when making that recipe
  #   # This can either be a regular bash script, or a function
  #   # that takes either one or two arguments, being:
  #   #   - getInput :: str -> TargetDef
  #   #       => given a target name, returns the TargetDef corresponding to it
  #   #   - getOutput
  #   #       => given an output name, returns a path to it store it, and adds
  #   #          it to the list of outputs of this rule/derivation
  #   cmd :: lines
  #        | (str -> TargetDef)@getInput -> lines
  #        | (str -> TargetDef)@getInput -> (str -> TargetDef)@getOutput -> lines
  #
  #   # A list of files that will also be outputted by this recipe.
  #   # By default, this is the target name, and anything referenced
  #   # with cmd's `getOutput`. Can be use to declare
  #   outputs :: [str]
  #     = [ <target name>, <stuff referenced with getOutput> ]
  # }
  #
  # # Just like Recipe but almost every `str` representing an input or
  # # output target can be a pattern string, in which any single '%' will be
  # # replaced with the captured part of the rule's name.
  # #
  # # For example, `"%.o" = mkPattern { buildInputs = [ "%.c" ]; }` will
  # # have the same semantics as an `%.o: %.c` rule in make. Note that we
  # # also apply that substitution in outputs (like cmd's getOutput),
  # # instead of using make's weird `$*` to refer to the capture.
  # PatternRecipe = Recipe // { ... }
}