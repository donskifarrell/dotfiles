{
  den.aspects.shell.bundles.base = {
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.coreutils
          pkgs.curl
          pkgs.dig
          pkgs.fd
          pkgs.file
          pkgs.findutils
          pkgs.inetutils
          pkgs.lsof
          pkgs.procs
          pkgs.psmisc
          pkgs.tcpdump
          pkgs.traceroute
          pkgs.unzip
          pkgs.wget
        ];
      };
  };
}
