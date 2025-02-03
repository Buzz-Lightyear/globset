# debug-glob.nix
{ pkgs, utf8 }:

let
  lib = pkgs.lib // { inherit utf8; };
  globset = import ./default.nix { inherit lib; };
  testRoot = ./test-data;

  # Test direct pattern matching first
  testDirectMatch = 
    let
      pattern = "foo\\*.gø";
      filename = "foo*.gø";
      result = globset.match pattern filename;
    in
    builtins.trace "Direct match test:"
    (builtins.trace "Pattern: ${pattern}"
    (builtins.trace "Filename: ${filename}"
    (builtins.trace "Result: ${builtins.toJSON result}")));

  # Test reading directory
  testReadDir = 
    let
      contents = builtins.readDir testRoot;
    in
    builtins.trace "\nDirectory contents:"
    (builtins.trace (builtins.toJSON contents));

  # Test full glob
  testGlob = 
    let
      testFileset = globset.globs testRoot [ "foo\\*.gø" ];
      result = map (p: lib.removePrefix "${toString testRoot}/" (toString p))
        (lib.fileset.toList testFileset);
    in
    builtins.trace "\nGlob test results:"
    (builtins.trace (builtins.toJSON result)
      result);

in
pkgs.writeText "debug-output" "Debug completed"