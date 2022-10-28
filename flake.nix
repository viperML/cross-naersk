{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-filter.url = "github:numtide/nix-filter";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
    nix-filter,
    fenix,
    naersk,
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      flake.overlays.default = final: prev: let
        inherit (nixpkgs) lib;

        src = nix-filter.lib {
          root = ./.;
          exclude = [
            (nix-filter.lib.matchExt "nix")
          ];
        };

        buildSystem = final.stdenv.buildPlatform.system;

        crossTargets = {
          "x86_64-unknown-linux-gnu" = {
            static = false;
            pkgs = import nixpkgs {
              system = buildSystem;
              crossSystem.config = "x86_64-unknown-linux-gnu";
            };
          };
          "aarch64-unknown-linux-gnu" = {
            static = false;
            pkgs = import nixpkgs {
              system = buildSystem;
              crossSystem.config = "aarch64-unknown-linux-gnu";
            };
          };
        };

        genCross = lib.genAttrs (builtins.attrNames crossTargets);
      in {
        _toolchainCross = genCross (
          targetConfig:
            with fenix.packages.${buildSystem};
              combine [
                (complete.withComponents [
                  "rustc"
                  "cargo"
                ])
                targets.${targetConfig}.latest.rust-std
              ]
        );

        cross-naersk = genCross (targetConfig:
          (naersk.lib.${buildSystem}.override {
            cargo = final._toolchainCross.${targetConfig};
            rustc = final._toolchainCross.${targetConfig};
          })
          .buildPackage {
            inherit src;
            CARGO_BUILD_TARGET = targetConfig;
            buildInputs = with crossTargets.${targetConfig}.pkgs; [
              stdenv.cc
            ];
          });
      };

      perSystem = {
        system,
        pkgs,
        ...
      }: {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };

        legacyPackages = pkgs;
      };
    };
}
