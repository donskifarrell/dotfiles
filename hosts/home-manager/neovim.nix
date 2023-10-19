{
  pkgs,
  lib,
  user,
  ...
}: {
  home = {
    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  programs.neovim = {
    enable = true;

    # extraConfig = builtins.concatStringsSep "\n" [
    #   (lib.strings.fileContents ./neovim/config.vim)

    #   ''
    #     lua << EOF
    #     ${lib.strings.fileContents ./neovim/config.lua}
    #     EOF
    #   ''
    # ];

    # extraPackages = with pkgs; [
    #   # installs different langauge servers for neovim-lsp
    #   # have a look on the link below to figure out the ones for your languages
    #   # https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
    #   nodePackages.typescript
    #   nodePackages.typescript-language-server

    #   shfmt
    #   gopls
    #   rnix-lsp
    # ];

    # plugins = with pkgs.vimPlugins; [
    #   vim-tmux-navigator
    #   nvim-lspconfig
    #   nvim-ts-rainbow
    #   nvim-ts-autotag
    #   The_NERD_Commenter
    #   fzf-vim
    #   vim-repeat
    #   # vim-surround # Conflicts with nerd commenter keys?
    #   vim-gitgutter # Need to customise colours
    #   vim-fugitive
    #   nvim-web-devicons
    #   lualine-nvim
    #   bufferline-nvim
    #   nvim-tree-lua
    #   nvim-colorizer-lua
    #   which-key-nvim

    #   (nvim-treesitter.withPlugins (
    #     # https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/development/tools/parsing/tree-sitter/grammars
    #     plugins:
    #       with plugins; [
    #         tree-sitter-lua
    #         tree-sitter-html
    #         tree-sitter-yaml
    #         tree-sitter-json
    #         tree-sitter-markdown
    #         tree-sitter-comment
    #         tree-sitter-bash
    #         tree-sitter-javascript
    #         tree-sitter-nix
    #         tree-sitter-typescript
    #         tree-sitter-query # for the tree-sitter itself
    #         tree-sitter-python
    #         tree-sitter-go
    #         tree-sitter-sql
    #         tree-sitter-graphql
    #         tree-sitter-dockerfile
    #         tree-sitter-fish
    #       ]
    #   ))
    # ];
  };
}
