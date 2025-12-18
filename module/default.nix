{ config, lib, nix-make, pkgs, ... }: with lib;
let
  ruleType = with types; oneOf [(functionTo ruleType) package];
in {
  options = {
    root = mkOption {
      description = ''
        The root directory to use for operations. Generally this is ./.
        This should not be a string but instead a literal, absolute path.
        It will be copied to the Nix store, and thus the build process should not go outside of it.
      '';
      example = "./.";
      type = types.path;
    };

    rules = mkOption {
      description = ''
        An attrset of target names and recipe values.
        A recipe can be a raw derivation (using `builtins.derivation` or `stdenv.mkDerivation`),
        but it can also be a function that takes in a "context" and returns a recipe.
        This context is the following attrset:
        {
          # Takes in a target name and returns the corresponding derivation.
          # Since Nix turns derivations into their path used inside of strings,
          # you can use this directly in commands in place of file names.
          dep :: (string | derivation) -> derivation

          # The name of the target being built.
          # For example, this might be "hello.o" (even if the rule is for "%.o")
          # If you want the name of the rule, use `ruleName`
          name :: string


        }
        The fact that a recipe can return another recipe allows chaining multiple definitions
        together that each need different parts of the context, without bloating the call site.
        It also means you can safely build basic utility functions and make them more complex
        later on without fear that you'll have to update every use of them.
      '';
      example = lib.literalExpression ''
        todo: write example of rules
      '';
      type = types.attrsOf ruleType;
    };

    derivationArgs = mkOption {
      description = ''
        The default `mkDerivation` arguments to use for recipe defined in [option]`config.rules`.
      '';
      example = {
        buildInputs = [ pkgs.hello ];
        preBuild = "echo 'Hello, world!'";
      };
      type = types.attrs;
    };

    defaultRule = mkOption {
      description = ''
        A function used to synthesize rules for targets which couldn't be matched against any other rule.
        It takes in the name of the target, and should return a rule.
        By default, it will assume the target is a filename or directory and simply copy it; it does not check (at eval time, not build time) if the target exists however.
        For example, this works well for source files.
      '';
      default = _: nix-make.utils.autoSrc;
      defaultText = lib.literalExpression ''
        _: nix-make.utils.autoSrc
      '';
      example = lib.literalExpression ''
        targetName: throw "Couldn't find target named ''${targetName}"
      '';
    };

    make = mkOption {
      description = ''
        The actual function that takes in a target name and returns the final derivation.
      '';
      visible = false;
    };
  };

  # we define it here (instead of in `mkOption.default`) because we want to
  # use `mkDefault` (instead `mkOptionDefault` like it would be otherwise)
  # so as to make sure this is merged with whatever else the user specifies.
  config.derivationArgs = mkDefault {
    # by default, don't require `src` to be set
    unpackPhase = "true";
  };

  config.make =
    let
      singleAttr =
        assert length (attrNames attrSet) == 1;
        rec {
          name = head (attrNames attrSet);
          value = getAttr name attrSet;
        };
     allRules = config.rules;
      findExactRule = target:
        let
          matches = lib.filterAttrs
            (ruleName: _: ruleName == target)
            allRules;
        in
          if (matches == {})
            then {}
            else singleAttr matches;
      findPatternRule = target:
        let
          matchesPattern = name: pattern: throw "not implemented";
          matches = lib.filterAttrs
            (pattern: _: matchesPattern target pattern)
            allRules;
          bestMatch = matches; # todo
        in
          if (matches == {})
            then {}
            else singleAttr bestMatch;
      makeRecipe = ctx: recipe:
        # we iterate/recurse make so that we can nest recipe objects.
        # for example, this allows us to do:
        #   foo = { dep, ... }: run "cat ${dep "bar"}"
        # where run = cmd: { ... }: pkgs.runCommand ...
        # thus, we can have an arbitrary number of functions that
        # can transparently request context without the consumer having
        # to care about it.
        if (lib.isDerivation recipe)
          then recipe
          else makeRecipe ctx (recipe ctx);
      make = target:
        let
          baseCtx = {
            dep = make;
            out = _: throw "sorry don't know how to handle multiple outputs right now";
            name = toString target;
            root = config.root;
            derivationArgs = config.derivationArgs;
          };
        in
        if (lib.isStringLike target)
          then
            let
              exactMatch = findExactRule target;
              patternMatch = findPatternRule target;
            in
              if (exactMatch != {})
                then
                  let ctx = baseCtx // { ruleName = exactMatch.name; };
                  in makeRecipe ctx exactMatch.value
              else if (patternMatch != {})
                then
                  let ctx = baseCtx // {
                    ruleName = patternMatch.name;
                    capture = patternMatch.value.capture;
                  };
                  in makeRecipe ctx patternMatch.value.recipe
              else
                  let ctx = baseCtx // {
                    ruleName = throw "Tried to use the name of an implicit recipe (which doesn't have one)";
                  };
                  in makeRecipe ctx (config.defaultRule target)
          else
            makeRecipe baseCtx target;
    in make;
}