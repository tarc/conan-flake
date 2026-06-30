{ ... }@args:
{
  conanFlake =
    let
      self = import ./. {
        inherit (args) inputs;
        conanFlake = self;
      };
    in
    self;
}
