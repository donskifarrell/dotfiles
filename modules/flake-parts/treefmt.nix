{ inputs, ... }:
{
  flake-file.inputs = {
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };
  };

  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    {
      inputs',
      config,
      pkgs,
      ...
    }:
    {
      devshells.default.packages = [ inputs'.statix.packages.default ];

      formatter = config.treefmt.build.wrapper;

      treefmt = {
        # inherit (config.flake-root) projectRootFile;
        projectRootFile = ".git/config";

        enableDefaultExcludes = true;

        settings = {
          # on-unmatched = "fatal";
          on-unmatched = "warn";

          global.excludes = [
            "generated/**"
            ".secrets/**"
            "*.editorconfig"
            "*.envrc"
            "*.gitconfig"
            "*.gitignore"
            "*CODEOWNERS"
            "*LICENSE"
            "*flake.lock"
            "*.svg"
            "*.png"
            "*.gif"
            "*.ico"
            "*.jpg"
            "*.webp"
            "*.conf"
            "*.age"
            "*.pub"
            "*.asc"
            "*.org"
            "*.zsh"
            "*.kdl"
            "*.txt"
            "*.tmpl"
            "*.jwe"
            "*.xml"
            "*.dds"
            "*.diff"
            "*.bin"
            # Underscore-prefixed files/dirs are ignored by the module auto-import system
            "**/_*/**"
            "**/_*"
          ];

          # statix.options = [ "explain" ];
          mdformat.options = [ "--number" ];
          shellcheck.options = [
            "--shell=bash"
            "--check-sourced"
          ];
          yamlfmt.options = [
            "-formatter"
            "retain_line_breaks=true"
          ];
          formatter = {
            # mdformat.options = [
            #   "--wrap"
            #   "keep"
            # ];
            prettier = {
              options = [
                "--tab-width"
                "2"
              ];
              # includes = [ "*.{css,html,js,json,jsx,scss,ts,yml,yaml}" ];
            };
          };
        };

        programs = {
          fish_indent.enable = true;
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
            includes = [ "**/*.nix" ];
          };
          # statix = {
          #   enable = true;
          #   package = inputs'.statix.packages.default;
          # };
          nixf-diagnose = {
            enable = true;
            ignore = [
              "sema-unused-def-lambda-witharg-formal"
              "sema-unused-def-lambda-noarg-formal"
              "sema-primop-overridden"
            ];
          };
          prettier = {
            enable = true;
            settings = {
              arrowParens = "always";
              bracketSameLine = false;
              bracketSpacing = true;
              editorconfig = true;
              embeddedLanguageFormatting = "auto";
              # experimentalTernaries = false;
              htmlWhitespaceSensitivity = "css";
              insertPragma = false;
              printWidth = 120;
              proseWrap = "always";
              quoteProps = "consistent";
              requirePragma = false;
              semi = true;
              singleAttributePerLine = true;
              singleQuote = false;
              trailingComma = "all";
              useTabs = false;

              tabWidth = 2;
            };
          };

          taplo.enable = true;

          yamlfmt = {
            enable = true;
          };

          toml-sort.enable = true;

          # mdformat.enable = true;

          shellcheck.enable = true;

        };
      };
    };
}
