# apps/media/yt-dlp — the yt-dlp downloader plus the media-downloader GUI front
# end. Ported from sini-nix modules/den/aspects/apps/media/yt-dlp.nix. First
# leaf under the apps/media category.
{
  den.aspects.apps.media.yt-dlp.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.media-downloader ];
      programs.yt-dlp.enable = true;
    };
}
