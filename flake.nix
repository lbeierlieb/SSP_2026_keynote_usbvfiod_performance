{
  description = "SSP 2026 keynote: 'usbvfiod: Insights into the Performance Aspects of USB Passthrough'";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forEachSystem (pkgs: rec {
        slides = pkgs.callPackage ./package.nix { };
        default = slides;

        # Dev server on the working tree (not the store), so edits hot-reload.
        dev = pkgs.writeShellApplication {
          name = "dev";
          runtimeInputs = [
            pkgs.nodejs
            pkgs.pnpm
          ];
          text = ''
            cd slides
            pnpm install --frozen-lockfile
            exec pnpm dev "$@"
          '';
        };
      });
    };
}
