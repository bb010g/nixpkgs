{
  lib,
  stdenv,
  lua,
  toVimPlugin,
}:
let
  inherit (lib) extends isFunction toExtension;

  # sanitizeDerivationName
  normalizeName = lib.replaceStrings [ "." ] [ "-" ];

  buildNeovimPlugin =
    fnOrAttrs:
    if isFunction fnOrAttrs then
      buildNeovimPluginExtensible fnOrAttrs
    else
      buildNeovimPluginExtensibleConst fnOrAttrs;

  buildNeovimPluginExtensible =
    rattrs:
    let
      # NOTE: The following is a hint that will be printed by the Nix cli when
      # encountering an infinite recursion. It must not be formatted into
      # separate lines, because Nix would only show the last line of the comment.

      # An infinite recursion here can be caused by having the attribute names of expression `e` in `.overrideNeovimAttrs(finalNeovimAttrs: previousNeovimAttrs: e)` depend on `finalNeovimAttrs`. Only the attribute values of `e` can depend on `finalAttrs`.
      args = rattrs (args // { inherit finalNeovimPackage overrideNeovimAttrs; });
      #              ^^^^

      overrideNeovimAttrs = f0: buildNeovimPluginExtensible (extends (toExtension f0) rattrs);

      finalNeovimPackage = buildNeovimPluginSimple overrideNeovimAttrs args;
    in
    finalNeovimPackage;

  # buildNeovimPluginExtensibleConst = attrs: buildNeovimPluginExtensible (_: attrs);
  # but pre-evaluated for a slight improvement in performance.
  buildNeovimPluginExtensibleConst =
    args:
    let
      overrideNeovimAttrs =
        f0:
        let
          f =
            self: super:
            let
              x = f0 super;
            in
            if isFunction x then f0 self super else x;
        in
        buildNeovimPluginExtensible (self: args // (if isFunction f0 then f self args else f0));

      finalNeovimPackage = buildNeovimPluginSimple overrideNeovimAttrs args;
    in
    finalNeovimPackage;

  buildNeovimPluginSimple =
    overrideNeovimAttrs:
    # function to create vim plugin from lua packages that are already packaged in
    # luaPackages
    {
      # the lua derivation to convert into a neovim plugin
      luaAttr ? (lua.pkgs.${normalizeName attrs.pname}),
      ...
    }@attrs:
    let
      originalLuaDrv =
        if (lib.typeOf luaAttr == "string") then
          lib.warn
            "luaAttr as string is deprecated since September 2024. Pass a lua derivation directly ( e.g., `buildNeovimPlugin { luaAttr = lua.pkgs.plenary-nvim; }`)"
            lua.pkgs.${normalizeName luaAttr}
        else
          luaAttr;

      luaDrv = originalLuaDrv.overrideAttrs (prevLuaDrvAttrs: {
        version = attrs.version or prevLuaDrvAttrs.version;
        rockspecVersion = prevLuaDrvAttrs.rockspecVersion;

        extraConfig =
          assert prevLuaDrvAttrs.extraConfig or "" == "";
          ''
            -- to create a flat hierarchy
            lua_modules_path = "lua"
          '';
      });

      finalDrv = toVimPlugin (
        luaDrv.overrideAttrs (
          prevLuaDrvAttrs:
          attrs
          // {
            nativeBuildInputs = prevLuaDrvAttrs.nativeBuildInputs or [ ] ++ [
              lua.pkgs.luarocksMoveDataFolder
            ];
            version = "${originalLuaDrv.version}-unstable-${prevLuaDrvAttrs.version}";
            passthru = attrs.passthru or { } // {
              inherit overrideNeovimAttrs;
            };
          }
        )
      );

    in
    finalDrv;

in
buildNeovimPlugin
