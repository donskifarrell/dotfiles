{
  stdenv,
  fetchFromGitHub,
}: {
  rofi-themes-collection = stdenv.mkDerivation rec {
    pname = "rofi-themes-collection";
    version = "1.4";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -rv $src/themes/ $out
    '';
    src = fetchFromGitHub {
      owner = "newmanls";
      repo = "rofi-themes-collection";
      rev = "a1bfac5627cc01183fc5e0ff266f1528bd76a8d2";
      sha256 = "sha256-0/0jsoxEU93GdUPbvAbu2Alv47Uwom3zDzjHcm2aPxY=";
    };
  };
}
