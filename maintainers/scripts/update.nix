{ package ? null
, maintainer ? null
, path ? null
, targetPkgs ? null
, max-workers ? null
, keep-going ? null
} @ args:

# TODO: add assert statements

let
  inherit (builtins) getAttr hasAttr throw;
  inherit (pkgs) lib;
  inherit (lib) attrByPath optional splitString;

  elemOrEqual = x: y:
    (builtins.isList x && builtins.elem y x) || y == x;

  # Remove duplicate elements from the list based on some extracted value.
  # O(n^2) complexity.
  nubOn = f: list:
    if list == [ ] then [ ] else let
      x = lib.head list;
      xs = lib.filter (p: f x != f p) (lib.drop 1 list);
    in [ x ] ++ nubOn f xs;

  # Try to evaluate `e` and return its result directly if successful, or a
  # default if not.
  tryEvalOr = default: e: let
      result = builtins.tryEval e;
    in if result.success then result.value else default;

  pkgs = import ./../../default.nix { overlays = [ ]; };

  targetPkgs = args.targetPkgs or pkgs;
  targetMaintainers = pkgs.lib.maintainers //
    attrByPath [ "targetPkgs" "lib" "maintainers" ] { } args;

  packagesWith = cond: return: set: let
      nestedPackages = lib.mapAttrsToList
        (name: pkg: tryEvalOr [ ] (
          if lib.isDerivation pkg && cond name pkg
            then [ (return name pkg) ]
          else if pkg.recurseForDerivations or false || pkg.recurseForRelease or false
            then packagesWith cond return pkg
          else [ ]))
        set;
    in nubOn (pkg: pkg.updateScript) (lib.flatten nestedPackages);

  packagesWithUpdateScriptAndMaintainer = let
      cond = name: pkg: pkg ? updateScript &&
        pkg.meta ? maintainers &&
        elemOrEqual maintainer pkg.meta.maintainers;
    in maintainer': let
      maintainer = if !(hasAttr maintainer' targetMaintainers)
        then throw
          "Maintainer with name `${maintainer'} does not exist in `maintainers/maintainer-list.nix`."
      else builtins.getAttr maintainer' targetMaintainers;
    in packagesWith cond (name: pkg: pkg) targetPkgs;

  packagesWithUpdateScript = let
      cond = name: pkg: pkg ? updateScript;
    in path: let
      attrSet = attrByPath (splitString "." path) null targetPkgs;
    in if attrSet == null
      then throw "Attribute path `${path}` does not exist."
    else packagesWith cond (name: pkg: pkg) attrSet;

  packageByName = name: let
      package = attrByPath (splitString "." name) null targetPkgs;
    in if package == null
      then throw "Package with attribute name `${name}` does not exist."
    else if !(package ? updateScript)
      then throw
        "Package with attribute name `${name}` does not have a `passthru.updateScript` attribute defined."
    else package;

  packages =
    if package != null
      then [ (packageByName package) ]
    else if maintainer != null
      then packagesWithUpdateScriptAndMaintainer maintainer
    else if path != null
      then packagesWithUpdateScript path
    else throw "No arguments provided.\n\n${helpText}";

  helpText = ''
    Please run:

        % nix-shell maintainers/scripts/update.nix --argstr maintainer garbas

    to run all update scripts for all packages that lists \`garbas\` as a maintainer
    and have \`updateScript\` defined, or:

        % nix-shell maintainers/scripts/update.nix --argstr package garbas

    to run update script for specific package, or

        % nix-shell maintainers/scripts/update.nix --argstr path gnome3

    to run update script for all package under an attribute path.

    You can also add

        --argstr max-workers 8

    to increase the number of jobs in parallel, or

        --argstr keep-going true

    to continue running when a single update fails.
  '';

  packageData = package: {
    name = package.name;
    pname = (builtins.parseDrvName package.name).name;
    updateScript = map builtins.toString (lib.toList package.updateScript);
  };

  packagesJson =
    pkgs.writeText "packages.json" (builtins.toJSON (map packageData packages));

  optionalArgs =
    optional (max-workers != null) "--max-workers=${max-workers}" ++
      optional (keep-going == "true") "--keep-going";

  scriptArgs = [ packagesJson ] ++ optionalArgs;

in pkgs.stdenv.mkDerivation {
  name = "nixpkgs-update-script";
  buildCommand = ''
    echo ""
    echo "----------------------------------------------------------------"
    echo ""
    echo "Not possible to update packages using \`nix-build\`"
    echo ""
    echo "${helpText}"
    echo "----------------------------------------------------------------"
    exit 1
  '';
  shellHook = ''
    unset shellHook # do not contaminate nested shells
    exec ${pkgs.python3.interpreter} ${./update.py} ${
      builtins.concatStringsSep " " scriptArgs
    }
  '';
}
