{
  pkgs,
  pname,
  version,
  src,
  mixDepsHash,
}: let
  beam = pkgs.beam-overlay;
  toolchain = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
  };

  lexborCommit = "244b84956a6dc7eec293781d051354f351274c46";
  lexborSrc = pkgs.fetchFromGitHub {
    owner = "lexbor";
    repo = "lexbor";
    rev = lexborCommit;
    hash = "sha256-Oup/lGU8a9Dqfho4Llg39t9Y9n4xfUmGk0772OkpnLQ=";
  };

  mixFodDeps = toolchain.beamScope.fetchMixDeps {
    inherit pname version src;
    mixEnv = "prod";
    hash = mixDepsHash;
  };

  mixFodDepsWithLexbor = pkgs.runCommand "${pname}-mix-deps-with-lexbor" {} ''
    mkdir -p "$out"
    cp -r --no-preserve=mode ${mixFodDeps}/. "$out/"

    lexbor_dir="$out/lazy_html/_build/c/third_party/lexbor/${lexborCommit}"
    mkdir -p "$(dirname "$lexbor_dir")"
    cp -r --no-preserve=mode ${lexborSrc} "$lexbor_dir"
  '';
in
  beam.mkPhoenixRelease {
    inherit toolchain pname version src;
    mixEnv = "prod";
    mixFodDeps = mixFodDepsWithLexbor;

    # LazyHTML's C++ NIF fetches Lexbor from GitHub unless its pinned source
    # is seeded into the dependency tree before Mix compiles dependencies.
    nativeBuildInputs = [pkgs.cmake];
    preConfigure = ''
      cat >> config/config.exs <<'EOF'
      config :elixir_make, :force_build, lazy_html: true
      EOF
    '';

    tailwindcss = pkgs.tailwindcss_4;
    esbuild = pkgs.esbuild;
  }
