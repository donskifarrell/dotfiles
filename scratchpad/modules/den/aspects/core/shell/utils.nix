{
  den.aspects.core.shell.utils = {
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.btop
          pkgs.coreutils
          pkgs.curl
          pkgs.fd
          pkgs.file
          pkgs.findutils
          pkgs.inetutils
          pkgs.tcpdump
          pkgs.traceroute
          pkgs.unzip
          pkgs.wget
          pkgs.busybox
        ];
      };
  };
}
