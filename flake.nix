{
  description = "Simplify Nix source management using familiar glob patterns";

  inputs.nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

  outputs = { self, nixpkgs-lib }:
    let 
      inherit (builtins)
        fromJSON
        readFile
      ;

      system = "x86_64-linux";

      nodes = (fromJSON (readFile ./dev/flake.lock)).nodes;

      inputFromLock = name:
        let locked = nodes.${name}.locked;
        in fetchTarball {
          url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
          sha256 = locked.narHash;
        };

      nixpkgs = inputFromLock "nixpkgs";

      pkgs = import nixpkgs { inherit system; };

      globset = import self { inherit (nixpkgs-lib) lib; };

      integration-tests = import ./integration-tests.nix { inherit pkgs; };
   
    in {
      lib = globset;

      tests.${system} = import ./internal/tests.nix {
        lib = nixpkgs-lib.lib // { inherit globset; };
      };

      packages.${system} = { inherit integration-tests; };

      checks.${system} = {
        default =
          pkgs.runCommand "tests" { nativeBuildInputs = [ pkgs.nix-unit ]; } ''
            export HOME="$(realpath .)"
            nix-unit \
              --eval-store "$HOME" \
              --extra-experimental-features flakes \
              --override-input nixpkgs-lib ${nixpkgs-lib} \
              --flake ${self}#tests
            touch $out
          '';

        inherit integration-tests;
      };
    };
}
