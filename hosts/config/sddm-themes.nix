{
  stdenv,
  fetchFromGitHub,
}: {
  sddm-catppuccin-frappe = stdenv.mkDerivation rec {
    pname = "sddm-catppuccin-frappe-theme";
    version = "1.0";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sddm/themes
      cp -aR $src/src/catppuccin-frappe $out/share/sddm/themes/catppuccin-frappe
    '';
    src = fetchFromGitHub {
      owner = "catppuccin";
      repo = "sddm";
      rev = "7fc67d1027cdb7f4d833c5d23a8c34a0029b0661";
      sha256 = "sha256-SjYwyUvvx/ageqVH5MmYmHNRKNvvnF3DYMJ/f2/L+Go=";
    };
  };
}
