# dev.tools.headless-browser — a browser a coding agent can actually *look*
# through: screenshots, DOM assertions, console-error checks against the UI it
# just wrote. Guest-only in practice (roles.sandbox.devenv and up); df's real hosts get
# real, graphical browsers from apps.bundles.browsers instead.
#
# Three ways in, because agents reach for different ones:
#   - `headless-chromium <url>` — the wrapper below, sane flags pre-applied
#     (e.g. `headless-chromium --screenshot=/tmp/ui.png --window-size=1280,800
#     http://localhost:5173`).
#   - playwright / puppeteer from the project's own node_modules — the env
#     vars below point both at store-provided browsers, so their post-install
#     downloads are skipped (a downloaded Chromium is dynamically linked
#     against paths that don't exist on NixOS and won't start).
#   - `playwright-mcp` — MCP server, so claude-code/omp can drive the browser
#     as a tool rather than by shelling out. Register per project with
#     `claude mcp add playwright -- playwright-mcp --headless --isolated`.
#
# The browser runs *inside* the guest, so it reaches the project's dev server
# on plain localhost — no `sandvm --port` forward needed for the agent's own
# checks (that flag is only for a human wanting to look from the host).
{
  den.aspects.dev.tools.headless-browser = {
    homeManager =
      { pkgs, lib, ... }:
      let
        # Chromium only: playwright's default browser set also builds/fetches
        # firefox + webkit (~1G of guest store closure) that nothing here
        # asks for. Flip these on if a project's playwright config wants
        # cross-browser runs.
        playwrightBrowsers = pkgs.playwright-driver.browsers.override {
          withFirefox = false;
          withWebkit = false;
        };
      in
      {
        home.packages = [
          pkgs.chromium
          # `playwright` CLI (codegen/test/screenshot), version-locked to the
          # driver whose browsers PLAYWRIGHT_BROWSERS_PATH points at.
          pkgs.playwright-test
          pkgs.playwright-mcp

          (pkgs.writeShellScriptBin "headless-chromium" ''
            # --disable-dev-shm-usage: chromium's default /dev/shm sizing
            # assumption is a classic crash source in VMs/containers.
            # --disable-gpu: nothing to accelerate with behind virtio.
            exec ${lib.getExe pkgs.chromium} \
              --headless=new \
              --disable-gpu \
              --disable-dev-shm-usage \
              --no-first-run \
              --no-default-browser-check \
              "$@"
          '')
        ];

        home.sessionVariables = {
          # Nixpkgs' prebuilt, patchelf'd browsers instead of playwright's own
          # downloads. Version coupling to know about: a project's own npm
          # `playwright` must match the driver's version (`playwright
          # --version` in the guest) — each release pins browser *revisions*,
          # and a mismatched one looks for a revision that isn't in this
          # linkFarm. Pin the project to it, or let that project download its
          # own browsers inside a devenv/FHS environment.
          PLAYWRIGHT_BROWSERS_PATH = "${playwrightBrowsers}";
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          # The host-requirements check shells out to ldd/ldconfig and always
          # "fails" on NixOS; the libraries are present via rpath.
          PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";

          PUPPETEER_SKIP_DOWNLOAD = "1";
          PUPPETEER_EXECUTABLE_PATH = lib.getExe pkgs.chromium;

          # What lighthouse, karma, vitest-browser, jest-puppeteer et al read.
          CHROME_PATH = lib.getExe pkgs.chromium;
          CHROME_BIN = lib.getExe pkgs.chromium;
        };
      };

    # Headless still rasterises text: with no fonts installed every screenshot
    # is tofu boxes, which makes visual validation worthless. The default set
    # is already in abhaile's store (core.desktop.fonts enables the same one),
    # so this costs the guest nothing extra.
    nixos = {
      fonts.enableDefaultPackages = true;
    };
  };
}
