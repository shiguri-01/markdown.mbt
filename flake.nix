{
  description = "MoonBit development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
    moonPprof = {
      url = "github:mizchi/moon-pprof";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      moonbit-overlay,
      moonPprof,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ moonbit-overlay.overlays.default ];
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          moon-pprof = pkgs.rustPlatform.buildRustPackage {
            pname = "moon-pprof";
            version = "0.1.1";
            src = moonPprof;
            cargoHash = "sha256-f4qdy/wy5fSTH4Ww6twDCaTUihUDsOK7fm8hHLbHkLU=";
            nativeBuildInputs = [ pkgs.protobuf ];
            cargoBuildFlags = [
              "--bin"
              "moon-pprof"
            ];
            doCheck = false;
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          moonbit-node = pkgs.runCommand "moonbit-node" {
            nativeBuildInputs = [ pkgs.makeWrapper ];
          } ''
            mkdir -p $out/bin
            makeWrapper ${pkgs.nodejs}/bin/node $out/bin/node
            makeWrapper ${pkgs.nodejs}/bin/node $out/bin/node.cmd
          '';
          markdown-compare = pkgs.buildNpmPackage {
            pname = "markdown-compare";
            version = "0.1.0";
            src = ./src/tools/benchmarks/compare;
            npmDepsHash = "sha256-/svFFUs9DK0knLzAm2GabSEBLfw26Bt3h5fnJ7j08xA=";
            dontNpmBuild = true;
            nativeBuildInputs = [
              pkgs.makeBinaryWrapper
            ];
            postInstall = ''
              rm $out/bin/markdown-compare
              makeWrapper ${pkgs.bun}/bin/bun $out/bin/markdown-compare \
                --add-flags $out/lib/node_modules/markdown-compare/run.mjs \
                --prefix PATH : ${
                  pkgs.lib.makeBinPath [
                    moonbit-node
                    pkgs.bun
                    pkgs.cmark
                    pkgs.moonbit-bin.moonbit.latest
                  ]
                }
            '';
          };
          basePackages = [
            moonbit-node
            pkgs.bun
            pkgs.cmark
            pkgs.git
            pkgs.just
            pkgs.lefthook
            markdown-compare
            pkgs.moonbit-bin.moonbit.latest
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.perf
          ];
        in
        {
          default = pkgs.mkShell {
            packages = basePackages;
            shellHook = ''
              if git rev-parse --git-dir >/dev/null 2>&1; then
                lefthook install
              fi
            '';
          };

          pprof = pkgs.mkShell {
            packages = basePackages ++ [
              self.packages.${system}.moon-pprof
            ];
            shellHook = ''
              if git rev-parse --git-dir >/dev/null 2>&1; then
                lefthook install
              fi
            '';
          };
        }
      );
    };
}
