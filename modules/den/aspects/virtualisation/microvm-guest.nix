# Guest-side shape of a `sandvm` sandbox — see modules/den/hosts/sandvm.nix
# for the host that carries this aspect, and docs/microvm-sandbox.md for the
# full picture (why 9p not virtiofs, why the SSH host key is shared not
# generated per-boot, what's deliberately NOT shared into the guest).
#
# Only the three scalars below are runtime-parameterized (via env vars the
# `sandvm` wrapper script sets before `nix run --impure`), read with
# `builtins.getEnv` — that's the one bit of impurity this whole feature
# needs; everything else here is ordinary static Nix.
{ inputs, lib, ... }:
let
  getEnvOr =
    name: default:
    let
      v = builtins.getEnv name;
    in
    if v == "" then default else v;

  # `nix flake check`/`nix build` evaluate `system.build.toplevel` purely
  # (no `--impure`), where `builtins.getEnv` always reads "" — so this can't
  # be a hard assertion (that would fail flake check for everyone, always).
  # Fall back to a real, harmless, always-present directory instead; `lib.warn`
  # surfaces the mistake without failing evaluation (this repo already runs
  # with `abort-on-warn = false`, so that's the established idiom here).
  workdirRaw = builtins.getEnv "MICROVM_WORKDIR";
  workdir =
    if workdirRaw == "" then
      lib.warn "MICROVM_WORKDIR unset — sharing /var/empty as /workspace. Launch via the `sandvm` command (pkgs/by-name/sandvm), not `nix run`/`nix build` directly." "/var/empty"
    else
      workdirRaw;
  vmName = getEnvOr "MICROVM_NAME" "sandvm";
  sshPort = lib.toIntBase10 (getEnvOr "MICROVM_SSH_PORT" "2222");
  vcpu = lib.toIntBase10 (getEnvOr "MICROVM_CPU" "4");
  mem = lib.toIntBase10 (getEnvOr "MICROVM_MEM" "4096");
  extraPorts =
    let
      raw = builtins.getEnv "MICROVM_PORTS";
    in
    map lib.toIntBase10 (lib.filter (s: s != "") (lib.splitString "," raw));

  # Same public key as modules/den/users/df.nix — it's public, safe to
  # duplicate; df's real private key/secrets never touch this guest (see
  # docs/microvm-sandbox.md, "what's not shared").
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.aspects.virtualization.microvm-guest.nixos =
    { ... }:
    {
      imports = [ inputs.microvm.nixosModules.microvm ];

      # Den sets networking.hostName from the static Den host name ("sandvm")
      # — mkForce so the per-launch instance name (e.g. the project's own
      # name) wins instead.
      networking.hostName = lib.mkForce vmName;

      microvm = {
        inherit vcpu mem;
        hypervisor = "qemu";

        # Usermode (SLIRP) networking: no host tap/bridge setup, host-only
        # reachability by design (matches "connections from the local
        # machine", not the LAN — see docs/microvm-sandbox.md).
        interfaces = [
          {
            type = "user";
            id = "usernet0";
            mac = "02:00:00:01:01:01";
          }
        ];

        forwardPorts = [
          {
            from = "host";
            host.port = sshPort;
            guest.port = 22;
          }
        ]
        ++ map (p: {
          from = "host";
          host.port = p;
          guest.port = p;
        }) extraPorts;

        # ro-store/hostkey stay 9p (built into qemu, no companion process,
        # and read-mostly so 9p's ownership quirks don't matter). workspace
        # is virtiofs: qemu's 9p "none"/"mapped" security models squash
        # pre-existing files' ownership to root as seen by the guest (they
        # only work for files the guest itself creates through the share, not
        # ones already on disk) since qemu runs unprivileged here — tried
        # both, neither let df write into an already-populated project dir.
        # virtiofsd passes through real host uid/gid directly, which just
        # works since the guest's df is uid 1000, matching the host. Costs a
        # companion `bin/virtiofsd-run` process (see the `sandvm` wrapper) —
        # see docs/microvm-sandbox.md for the full story.
        shares = [
          {
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
          {
            tag = "workspace";
            proto = "virtiofs";
            source = workdir;
            mountPoint = "/workspace";
          }
          {
            tag = "hostkey";
            source = "/var/lib/sandvm/hostkey";
            mountPoint = "/etc/sandvm-hostkey";
          }
        ];

        # Host's /nix/store is shared read-only (above) — without this, the
        # guest's entire /nix/store is read-only and nix-daemon auto-disables
        # (it "works only with a writable /nix/store", per microvm.nix), which
        # breaks home-manager activation *and* the actual point of having
        # devenv.sh in the guest: installing a project's own dependencies at
        # runtime. This overlay is what makes that possible. It's an
        # auto-created disk image, not a share, per microvm.nix's own
        # constraint (overlayfs can't use 9p/virtiofs as an upper layer) — the
        # `sandvm` wrapper runs qemu with its CWD set to the per-instance
        # state dir, so the relative path below lands there, not in the
        # project folder.
        writableStoreOverlay = "/nix/.rw-store";
        volumes = [
          {
            image = "nix-store-overlay.img";
            mountPoint = "/nix/.rw-store";
            size = 8192;
          }
        ];
      };

      # roles.default's core.nix sets this repo-wide for disk savings; it's
      # asserted incompatible with microvm.writableStoreOverlay above.
      nix.settings.auto-optimise-store = lib.mkForce false;

      # `core.network.openssh` (via roles.default) already enables sshd with
      # publickey-only auth, no root password login, agent forwarding on —
      # exactly what's wanted here. Only `hostKeys` is guest-specific.
      services.openssh.hostKeys = [
        {
          path = "/etc/sandvm-hostkey/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      users.users.df.openssh.authorizedKeys.keys = [ authorizedKey ];

      # Console fallback: df/root have no password set (deliberately — SSH
      # pubkey is the intended path in), which meant a broken SSH connection
      # left the console login prompt with no usable credentials at all,
      # locking out debugging exactly when it's needed. Autologin instead —
      # same pattern as virtualisation/vm-login.nix's debug-VM convenience.
      # Not a security regression: the console is qemu's own stdout, only
      # ever reachable by whoever can already read the `sandvm`-launching
      # systemd-run unit (df on the host) — the same principal SSH already
      # trusts.
      services.getty.autologinUser = "df";
    };
}
