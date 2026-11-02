{lib}: let
  normalize = import ../lib/options.nix {inherit lib;};
  rejects = options:
    !(builtins.tryEval (builtins.deepSeq (normalize options) true)).success;

  defaults = normalize {};
  fullShape = normalize {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
    gleam.enable = true;
    tools = {
      phx_new.enable = true;
      igniter_new.enable = true;
      livebook.enable = true;
      tailwindcss = {
        enable = true;
        major = 4;
      };
      esbuild.enable = true;
    };
    extraPackages = ["extra-package"];
  };
in
  assert defaults.elixir.enable;
  assert defaults.elixir.version == "latest";
  assert defaults."erlang-otp".version == null;
  assert fullShape.tools.phx_new.enable;
  assert fullShape.tools.tailwindcss.major == 4;
  assert fullShape.extraPackages == ["extra-package"];
  assert rejects {tools.pheonix.enable = true;};
  assert rejects {tools.tailwindcss.major = 5;};
  assert rejects {elixir.enable = "yes";};
  assert rejects {
    elixir.enable = false;
    tools.phx_new.enable = true;
  }; true
