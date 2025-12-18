{ config, lib, pkgs, ... }: with lib;
let
  recipeType = with types; oneOf [(functionTo recipeType) package];
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
      type = types.attrsOf recipeType;
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
      defaultText = "Throws an error about not knowing how to make the target.";
      example = lib.literalExpression ''
        _: nix-make.utils.autoSrc
      '';
    };

    make = mkOption {
      description = ''
        The actual function that takes in a target name and returns the final derivation.
      '';
      visible = false;
    };
  };

  config.defaultRule = mkOptionDefault (target: throw (
    ''
      need to make target '${target}', but no rule was found for it.

      hint: in case '${target}' is a source file, you should add a rule
            for it:
                rules = {
                  "${target}" = nix-make.utils.autoSrc;
                };
    '' +
      optionalString (hasInfix "." target)
    ''

      note: you might want to use pattern rules (e.g. '%.c') to specify
            source files:
                rules = {
                  "%.${last (splitString "." target)}" = nix-make.utils.autoSrc;
                };
    '' +
    ''

      note: alternatively, you can also set the `defaultRule` top-level
            attribute if you want to change the default behavior when a
            target isn't found:
                defaultRule = targetName: nix-make.utils.autoSrc;
    ''
  ));

  # we define it here (instead of in `mkOption.default`) because we want to
  # use `mkDefault` (instead `mkOptionDefault` like it would be otherwise)
  # so as to make sure this is merged with whatever else the user specifies.
  config.derivationArgs = mkDefault {
    # by default, don't require `src` to be set
    unpackPhase = "true";
  };

  config.make =
    let
      filterAttrNames = f: filterAttrs (name: _: f name);
      singleAttr = attrSet:
        let
          attrs = attrsToList attrSet;
        in
          assert length attrs == 1;
          head attrs;

      allRules = config.rules;

      findExactRule = target:
        let
          matches = filterAttrNames
            (ruleName: ruleName == target)
            allRules;
        in
          if (matches == {})
            then {}
            else singleAttr matches;

      findPatternRule = target:
        let
          # filters rules down to only the ones whose name is a pattern
          patternRules = filterAttrNames (hasInfix "%") allRules;

          headOrNull = list:
            if (!lib.isList list || list == [])
              then null
              else head list;

          # Pattern -> Regex
          patternToRegex = pattern:
            assert count (c: c == "%") (stringToCharacters pattern) <= 1
              || throw "nix-make doesn't support patterns with multiple stems (%)";
            replaceString "%" "(.*)" (escapeRegex pattern);

          # Pattern -> TargetName -> [captures]
          matchPattern = pattern: name:
            builtins.match (patternToRegex pattern) name;

          # { Pattern = Recipe } -> { Pattern = { "captures" :: str, "recipe" :: Recipe }}
          allMatchInfo = mapAttrs
            (pattern: recipe: {
              capture = headOrNull (matchPattern pattern target);
              inherit recipe;
            })
            patternRules;

          # filters the results from `allMatchInfo` down to only the
          # rules that matched against something (i.e. have a capture)
          matches = filterAttrs
            (_: info: info.capture != null)
            allMatchInfo;

          # we rank matches based on how specific they are.
          # since we only allow one capture per pattern for now, we can just
          # select the match that has the shortest capture. this gives a
          # "score," where a lower score indicates a better match.
          #
          # for example, let's say we want to build target 'foo.o' and we
          # have two rules that match: '%.o' and '%'.
          # since '%.o' is more specific, it should be chosen over '%'.
          # looking at the capture length, '%.o' only captures "foo", while
          # '%' captures "foo.o", so '%.o' has a lower score than '%'.
          # therefore, we would choose '%.o' over '%'.
          scoreMatch = info:
            stringLength info.value.capture;

          # a target might match multiple pattern (e.g. '%' and '%.o'), so we
          # need to sort these to select the best one (see `scoreMatch` above)
          rankedMatches = sortOn
            scoreMatch
            (attrsToList matches);

          bestMatch = head rankedMatches;
        in
          if (matches == {})
            then {}
            else bestMatch;

      makeRecipe = ctx: recipe:
        if (lib.isStringLike recipe) then
          _makeStringLike ctx recipe
        else
          # we iterate/recurse make so that we can nest recipe objects.
          # for example, this allows us to do:
          #   foo = { dep, ... }: run "cat ${dep "bar"}"
          # where run = cmd: { ... }: pkgs.runCommand ...
          # thus, we can have an arbitrary number of functions that
          # can transparently request context without the consumer having
          # to care about it.
          makeRecipe ctx (recipe ctx);

      _makeFromTargetName = baseCtx: target:
        assert lib.isString target;
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
              in makeRecipe ctx (config.defaultRule target);

      _makeStringLike = baseCtx: target:
        # if it's just a derivation, return the derivation directly
        if (lib.isDerivation target) then
          target
        else if (lib.isStorePath "${target}") then
          # note: NOT `toString`! toString strips context (e.g. path-ness) from string-likes
          "${target}"
        else
          throw ''
            Calling 'make' or 'dep' on a ${lib.typeOf target} is not supported (yet).
            The value was:
              ${target} (or ${toString target})
            which is not a derivation or store path.
            For paths, see #3 and comment if you need it or want help, or open an
            issue if that doesn't fit.
          '';

      make = target:
        let
          baseCtx = {
            dep = make;
            out = _: throw "sorry don't know how to handle multiple outputs right now :(";
            name = toString target;
            root = config.root;
            derivationArgs = config.derivationArgs;
          };
        in
        # not isStringLike because derivations (and paths)
        # should not be treated as target names.
        if (lib.isString target) then
          _makeFromTargetName baseCtx target
        else if (lib.isStringLike target) then
          _makeStringLike baseCtx target
        else
          makeRecipe baseCtx target;
    in make;
}