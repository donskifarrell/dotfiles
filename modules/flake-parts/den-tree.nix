# Exposes `flake.lib.den-tree`: a rendered tree of the Den aspects applied to
# each host and each of its users (the entity's root-aspect includes, expanded
# recursively). Consumed by the `den-tree` devshell command
# (pkgs/by-name/den-tree) via `nix eval --raw .#lib.den-tree`. (Not a
# top-level `den-tree` output: `.#den-tree` would resolve to the package of
# the same name.)
#
# Aspect objects only carry their leaf name, so a name -> full-path map is
# built by walking the den.aspects tree; ambiguous leaves (e.g. `amd` for both
# hardware.cpu.amd and hardware.gpu.amd) list their candidate paths. Class
# tags ([nixos], [homeManager], ...) mark which config domains an aspect
# defines directly.
{ config, lib, ... }:
let
  classNames = builtins.attrNames config.den.classes;

  # Keys on an aspect object that are never sub-aspects.
  structuralKeys = [
    "_"
    "__contentValues"
    "__functor"
    "__provider"
    "__providesForwarded"
    "classes"
    "description"
    "excludes"
    "includes"
    "meta"
    "name"
    "policies"
    "provides"
  ];

  # Distinguishes (sub-)aspects from class content (`nixos = <module>`, ...):
  # an aspect defines content for some class (a class-named key), has its own
  # includes, or is a pure container (e.g. hardware.cpu) whose direct children
  # do. Class-content wrappers have none of these. The child check is
  # deliberately one level deep — recursing further forces lazy module content
  # (which may require module args like `pkgs`) and blows up evaluation.
  # Nested sub-aspects carry no `name`; the walk falls back to the attr key.
  hasClassKey = v: builtins.any (c: builtins.hasAttr c v) classNames;
  isAspect =
    v:
    builtins.isAttrs v
    && (
      hasClassKey v
      || v ? includes
      || builtins.any (
        k:
        !(builtins.elem k structuralKeys)
        && (
          let
            c = v.${k};
          in
          builtins.isAttrs c && (hasClassKey c || c ? includes)
        )
      ) (builtins.attrNames v)
    );

  subAspectsOf = a: lib.filterAttrs (k: v: !(builtins.elem k structuralKeys) && isAspect v) a;

  walkPaths =
    path: aspects:
    lib.concatLists (
      lib.mapAttrsToList (
        k: v:
        let
          p = path ++ [ k ];
        in
        [
          {
            name = v.name or k;
            path = lib.concatStringsSep "." p;
          }
        ]
        ++ walkPaths p (subAspectsOf v)
      ) aspects
    );

  pathsByName = lib.groupBy (e: e.name) (
    walkPaths [ ] (lib.filterAttrs (_: isAspect) config.den.aspects)
  );

  classTags = a: builtins.filter (c: builtins.hasAttr c a && !(isAspect a.${c})) classNames;

  label =
    a:
    let
      n = a.name or "?";
      paths = map (e: e.path) (pathsByName.${n} or [ ]);
      base =
        if lib.hasPrefix "[definition" n then
          "(inline module)"
        else if builtins.length paths == 1 then
          builtins.head paths
        else if paths == [ ] then
          n
        else
          "${n} (${lib.concatStringsSep " or " paths})";
      tags = classTags a;
    in
    base + lib.optionalString (tags != [ ]) "  [${lib.concatStringsSep " " tags}]";

  # Expand an aspect's includes, guarding against include cycles by name.
  # Anonymous aspects ("[definition …]") share synthesized names, so they are
  # exempt from the guard to avoid false cycle flags.
  aspectNode =
    ancestry: a:
    let
      n = a.name or "?";
      anonymous = lib.hasPrefix "[definition" n;
    in
    if !anonymous && builtins.elem n ancestry then
      {
        label = "${label a}  (cycle)";
        children = [ ];
      }
    else
      {
        label = label a;
        children = map (aspectNode (ancestry ++ lib.optional (!anonymous) n)) (a.includes or [ ]);
      };

  renderNodes =
    prefix: nodes:
    lib.concatLists (
      lib.imap0 (
        i: nd:
        let
          isLast = i == (builtins.length nodes - 1);
        in
        [ "${prefix}${if isLast then "└─ " else "├─ "}${nd.label}" ]
        ++ renderNodes "${prefix}${if isLast then "   " else "│  "}" nd.children
      ) nodes
    );

  hostBlocks = lib.concatLists (
    lib.mapAttrsToList (
      system: hosts:
      lib.mapAttrsToList (
        hostName: host:
        let
          aspectNodes = map (aspectNode [ ]) (host.aspect.includes or [ ]);
          userNodes = lib.mapAttrsToList (userName: user: {
            label = "user:${userName}";
            children = map (aspectNode [ ]) (user.aspect.includes or [ ]);
          }) (host.users or { });
        in
        lib.concatStringsSep "\n" (
          [ "${hostName} (${system})" ] ++ renderNodes "" (aspectNodes ++ userNodes)
        )
      ) hosts
    ) config.den.hosts
  );
in
{
  flake.lib.den-tree = lib.concatStringsSep "\n\n" hostBlocks + "\n";
}
