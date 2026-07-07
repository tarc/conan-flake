{ ... }@args:
{
  conanFlakeLib =
    let
      self = import ./. {
        inherit (args) inputs;
        conanFlakeLib = self;
      };
    in
    self;
}
