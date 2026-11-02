{lib}: let
  manifests = import ../lib/manifests.nix {inherit lib;};
  versions = manifests.versions;
  stableVersions = lib.filterAttrs (version: _: !(lib.hasInfix "-rc" version)) versions;
  sortedStableVersions = lib.sort (left: right: lib.versionOlder left right) (lib.attrNames stableVersions);
  expectedLatest = lib.last sortedStableVersions;
  pinned = versions."1.19.7";
  current = versions."1.20.5";
in
  assert builtins.length (lib.attrNames versions) >= 53;
  assert manifests.latest == expectedLatest;
  assert builtins.hasAttr "1.20.0-rc.6" versions;
  assert pinned.sha256 == "1cqpyjdbsy6zijyzbqlp0qrbwcj5i3dv466zjh9vlpxbxllhiym8";
  assert pinned.minOtpVersion == "25";
  assert pinned.maxOtpVersion == "28";
  assert current.minOtpVersion == "27";
  assert current.maxOtpVersion == "29"; {
    count = builtins.length (lib.attrNames versions);
    latest = manifests.latest;
    includesReleaseCandidates = builtins.hasAttr "1.20.0-rc.6" versions;
    usesJsonData = builtins.isString pinned.sha256;
  }
