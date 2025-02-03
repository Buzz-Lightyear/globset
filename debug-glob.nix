# debug-glob.nix
{ pkgs, utf8 }:

let
  lib = pkgs.lib // { inherit utf8; };
  globset = import ./default.nix { inherit lib; };
  testRoot = ./test-data;

  # Helper function to inspect file matching
  debugMatch = name: pattern:
    let
      result = globset.match pattern name;
      chars = lib.stringToCharacters name;
      patternChars = lib.stringToCharacters pattern;
      
      # Convert to hex for debugging
      toHex = str: 
        builtins.concatStringsSep " " 
          (map (c: builtins.toJSON (builtins.fromJSON (builtins.toJSON (builtins.charToInt c)))) 
            (lib.stringToCharacters str));
    in
    {
      inherit pattern name result;
      nameHex = toHex name;
      patternHex = toHex pattern;
    };

  # Test files to check
  testFiles = [
    "gø.foo"
    "foo.gø"
  ];

  # Patterns to test
  patterns = [
    "gø.*"
    "**/*.gø"
  ];

  # Run tests and collect results
  results = {
    # Test direct pattern matching
    patternMatches = builtins.listToAttrs (
      builtins.concatMap (file:
        map (pattern: {
          name = "${file}-${pattern}";
          value = debugMatch file pattern;
        }) patterns
      ) testFiles
    );

    # Test directory reading
    dirContents = builtins.readDir testRoot;

    # Test full glob results
    globResults = globset.globs testRoot patterns;
  };

in
  pkgs.writeText "debug-results" (builtins.toJSON results)