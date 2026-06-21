{
  den.aspects.core.nix = {
    os = {
      nix = {
        settings = {
          experimental-features = [
            "flakes"
            "nix-command"
            "pipe-operators"
          ];

          allow-import-from-derivation = true;
          auto-optimise-store = true;
          connect-timeout = 10;
          http-connections = 128;
          max-jobs = "auto";
          max-substitution-jobs = 64;
          use-xdg-base-directories = true;

          substituters = [
            "https://cache.nixos.org/"
            "https://nix-community.cachix.org"
            "https://numtide.cachix.org"
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          ];

        };

        gc = {
          automatic = true;
          options = "--delete-older-than 8d";
        };
      };
    };

    darwin = {
      nix.settings =
        let
          users = [
            "root"
            "@admin"
          ];
        in
        {
          trusted-users = users;
          allowed-users = users;
        };

      nix.gc.interval = {
        Hour = 5;
        Minute = 0;
      };
    };

    nixos =
      { lib, ... }:
      {
        nix = {
          settings =
            let
              users = [
                "root"
                "@wheel"
              ];
            in
            {
              trusted-users = users;
              allowed-users = users;
            };

          gc.dates = "05:00";
        };

        # OOM prevention: separate slice for nix-daemon
        systemd = {
          slices."nix-daemon".sliceConfig = {
            ManagedOOMMemoryPressure = "kill";
            ManagedOOMMemoryPressureLimit = "50%";
          };
          services."nix-daemon".serviceConfig = {
            Slice = "nix-daemon.slice";
            OOMScoreAdjust = lib.mkDefault 250;
          };
          services.nix-gc.serviceConfig = {
            CPUSchedulingPolicy = "batch";
            IOSchedulingClass = "idle";
            IOSchedulingPriority = 7;
          };
        };
      };
  };
}
