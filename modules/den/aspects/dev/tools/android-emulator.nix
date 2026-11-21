# dev/tools/android-emulator — host-side Android 35 emulator (x86_64
# google_apis on KVM, host GPU), so sandboxes can deploy without USB. Run
# `android-emulator`; the first launch creates the AVD in ~/.android/avd and
# later launches reuse it. A guest attaches with `adb connect 10.0.2.2:5555`
# (SLIRP's alias for host loopback, where the emulator's adb port listens).
# Any running sandbox can reach that port too, so only run it while needed.
{
  den.aspects.dev.tools.android-emulator.nixos =
    { pkgs, ... }:
    let
      emulator = (pkgs.androidenv.override { licenseAccepted = true; }).emulateApp {
        name = "android-emulator";
        platformVersion = "35";
        abiVersion = "x86_64";
        systemImageType = "google_apis";
        deviceName = "bbm35";
        # Quoted heredoc in run-test-emulator: $HOME expands at launch.
        androidUserHome = "$HOME/.android";
        configOptions = {
          "hw.gpu.enabled" = "yes";
          "hw.gpu.mode" = "host";
          "hw.keyboard" = "yes";
        };
      };
    in
    {
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "android-emulator" ''exec ${pkgs.lib.getExe emulator} "$@"'')
      ];
    };
}
