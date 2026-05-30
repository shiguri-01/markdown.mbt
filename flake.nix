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
          compareSrc = pkgs.lib.cleanSourceWith {
            src = ./src/tools/benchmarks/compare;
            filter =
              path: _type:
              let
                name = baseNameOf path;
              in
              name != ".generated" && name != "node_modules";
          };
          markdown-compare-node-modules = pkgs.stdenvNoCC.mkDerivation {
            pname = "markdown-compare-node-modules";
            version = "0.1.0";
            src = compareSrc;
            nativeBuildInputs = [ pkgs.bun ];
            dontConfigure = true;
            buildPhase = ''
              runHook preBuild
              bun install --frozen-lockfile --no-progress
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib
              rm -rf node_modules/.cache node_modules/.bin
              cp -R node_modules $out/lib/node_modules
              runHook postInstall
            '';
            outputHash = "sha256-G+fp9T/AbKOyh4Kqg8UmVOyREmIocC9vcIJycdRSntg=";
            outputHashMode = "recursive";
          };
          markdown-compare = pkgs.stdenvNoCC.mkDerivation {
            pname = "markdown-compare";
            version = "0.1.0";
            src = compareSrc;
            nativeBuildInputs = [
              pkgs.makeBinaryWrapper
            ];
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin $out/lib/markdown-compare
              cp -R . $out/lib/markdown-compare
              ln -s ${markdown-compare-node-modules}/lib/node_modules $out/lib/markdown-compare/node_modules
              makeWrapper ${pkgs.bun}/bin/bun $out/bin/markdown-compare \
                --add-flags "run --prefer-offline --no-install $out/lib/markdown-compare/run.ts" \
                --prefix PATH : ${
                  pkgs.lib.makeBinPath [
                    moonbit-node
                    pkgs.bun
                    pkgs.cmark
                    pkgs.moonbit-bin.moonbit.latest
                  ]
                }
              runHook postInstall
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
