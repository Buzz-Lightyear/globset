with import <nixpkgs> {};
let
  lib = pkgs.lib;
  pattern = import ./internal/src/pattern.nix { inherit lib; };
in
pattern.expandAlternates "src/{,test/}*.c"