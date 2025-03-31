{
  description = "Manage your Distro containers declaratively!";

  outputs = {self, ...}: {
    nixosModules = rec {
      distronix = import ./nixosModule.nix;
      default = distronix;
    };
    nixosModule = self.nixosModules.distronix;
  };
}
