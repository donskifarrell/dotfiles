# dev/lang/android — headless Android build toolchain: JDK 17, Gradle 8.9,
# SDK platform 35, build-tools 35.0.0, platform-tools (adb). No Studio,
# emulator, system images or NDK. Phone link from a sandbox = Wireless
# debugging (`adb pair`/`adb connect <phone-ip>:<port>`); guests have no USB.
{
  den.aspects.dev.lang.android.homeManager =
    { pkgs, ... }:
    let
      sdk =
        ((pkgs.androidenv.override { licenseAccepted = true; }).composeAndroidPackages {
          platformVersions = [ "35" ];
          buildToolsVersions = [ "35.0.0" ];
          includeEmulator = false;
          includeSystemImages = false;
          includeNDK = false;
          includeSources = false;
        }).androidsdk;
      androidHome = "${sdk}/libexec/android-sdk";
      # nixpkgs only carries the latest 8.x; AGP 8.7 project pins 8.9.
      gradle =
        (pkgs.gradle-packages.mkGradle {
          version = "8.9";
          hash = "sha256-1yXXB7+r1N/clYxiQAOzyArMwD9wN7USLEsdDvFc7Ks=";
          defaultJava = pkgs.jdk17;
        }).wrapped;
    in
    {
      programs.java = {
        enable = true;
        package = pkgs.jdk17;
      };
      home.packages = [
        sdk
        gradle
      ];
      home.sessionVariables = {
        ANDROID_HOME = androidHome;
        ANDROID_SDK_ROOT = androidHome;
        # AGP's Maven aapt2 is a generic-linux binary; use the SDK's patched one.
        GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidHome}/build-tools/35.0.0/aapt2";
      };
    };
}
