{
  config.flake.nixosModules.printing = _: {
    config = {
      # Enable CUPS to print documents.
      services.printing.enable = true;
    };
  };
}
