{
  den.aspects.core.disable-docs = {
    nixos = {
      # https://mastodon.online/@nomeata/109915786344697931
      documentation = {
        enable = false;
        man.enable = true;
        doc.enable = false;
        info.enable = false;
        nixos.enable = false;
      };
    };
  };
}
