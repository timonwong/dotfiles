# FIXME(nixpkgs#513019): direnv 2.37.1 can hang in checkPhase while running
# shell integration tests. Keep this overlay until nixpkgs carries the fix.
# - Issue: https://github.com/NixOS/nixpkgs/issues/513019
# - Fix:   https://github.com/NixOS/nixpkgs/pull/513081
# - Root:  https://github.com/NixOS/nix/pull/15638
{ lib }:
_: prev: {
  direnv =
    assert lib.assertMsg (prev.direnv.version == "2.37.1" && (prev.direnv.doCheck or true))
      "Overlay nix-config/overlays/direnv.nix may no longer be needed: direnv=${prev.direnv.version}, doCheck=${
        lib.boolToString (prev.direnv.doCheck or true)
      }. Try removing the overlay.";
    prev.direnv.overrideAttrs (_: {
      doCheck = false;
    });
}
