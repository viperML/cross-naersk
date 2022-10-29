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
        targetConfig = final.stdenv.targetPlatform.config;
        targetConfigUpper = builtins.replaceStrings ["-"] ["_"] (lib.toUpper targetConfig);
      in {
        _toolchain = with fenix.packages.${buildSystem};
          combine [
            (complete.withComponents [
              "rustc"
              "cargo"
            ])
            targets.${targetConfig}.latest.rust-std
          ];

        naersk = final.callPackage naersk {
          cargo = final._toolchain;
          rustc = final._toolchain;
        };

        cross-naersk = final.naersk.buildPackage {
          inherit src;
          CARGO_BUILD_TARGET = targetConfig;
        };

        cross-rustplatform =
          (final.makeRustPlatform {
            cargo = final._toolchain;
            rustc = final._toolchain;
          })
          .buildRustPackage {
            inherit src;
            pname = "cross-rustplatform";
            version = "0.pre";
            cargoLock.lockFile = ./Cargo.lock;
            target = targetConfig;
          };
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
