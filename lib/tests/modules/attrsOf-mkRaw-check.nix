{ config, lib, ... }: {
  options.mkRawWorks = lib.mkOption {
    default = config.value.foo == "should be defined" &&
      ! config.value ? bar &&
      config.value.baz == lib.mkIf false "should not be defined";
  };

  config.value.foo = lib.modules.mkRaw "should be defined";
  config.value.bar = lib.mkIf false (lib.modules.mkRaw "should not be defined");
  config.value.baz = lib.modules.mkRaw (lib.mkIf false "should not be defined");
}
