{lib, ...}: let
  versions = {
    "1.18.4" = {
      sha256 = "1q5m4v2gqh4xf3hvqbr3pn3090f6x7h60id7vbcdl30nj856q4wf";
      url = "https://codeload.github.com/elixir-lang/elixir/tar.gz/refs/tags/v1.18.4";
      minOtpVersion = "25";
      maxOtpVersion = "28";
    };
    "1.17.3" = {
      sha256 = "141qpxg8v58bbvk7346d8m6ml4lpkszsrgnf80931v31br6w25k1";
      url = "https://codeload.github.com/elixir-lang/elixir/tar.gz/refs/tags/v1.17.3";
      minOtpVersion = "25";
      maxOtpVersion = "27";
    };
    "1.16.0" = {
      sha256 = "067a1ba4q4sxwx63932hwcqjyv68h34253b16917gjc57hg69znp";
      url = "https://codeload.github.com/elixir-lang/elixir/tar.gz/refs/tags/v1.16.0";
      minOtpVersion = "24";
      maxOtpVersion = "26";
    };
    "1.15.4" = {
      sha256 = "072hjabvy66lmz4689gwwkipnwsqpfk0231sdj7si4mpb83gharh";
      url = "https://codeload.github.com/elixir-lang/elixir/tar.gz/refs/tags/v1.15.4";
      minOtpVersion = "24";
      maxOtpVersion = "26";
    };
  };

  latest = "1.18.4";
in {
  inherit versions latest;
}
