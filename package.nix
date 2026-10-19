{
  stdenv,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs,
  pnpm,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ssp-2026-keynote-usbvfiod-performance";
  version = "0.1.0";

  src = ./slides;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    hash = "sha256-ShmyFUc5EuhyRknaKNJ6h8BcY6EE1teWH+BZJVYWwGs=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild
    pnpm exec slidev build --base "$SLIDEV_BASE" --out dist
    runHook postBuild
  '';

  SLIDEV_BASE = "/SSP_2026_keynote_usbvfiod_performance/";

  installPhase = ''
    runHook preInstall
    cp -r dist "$out"
    runHook postInstall
  '';
})
