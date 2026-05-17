{
  description = "MoonBit development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
  };

  outputs =
    {
      nixpkgs,
      moonbit-overlay,
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
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          markdown-compare = pkgs.buildNpmPackage {
            pname = "markdown-compare";
            version = "0.1.0";
            src = ./bench/compare;
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
                    pkgs.bun
                    pkgs.cmark
                    pkgs.moonbit-bin.moonbit.latest
                  ]
                }
            '';
          };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              bun
              cmark
              git
              just
              lefthook
              markdown-compare
              moonbit-bin.moonbit.latest
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
