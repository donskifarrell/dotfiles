{
  den.aspects.core.security.tpm2 = {
    nixos = _: {
      security.tpm2 = {
        enable = true;
        abrmd.enable = true;
        pkcs11.enable = true;
        tctiEnvironment.enable = true;
      };
    };
  };
}
