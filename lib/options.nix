{lib}: rawOptions: let
  levenshtein = left: right: let
    rightCharacters = lib.stringToCharacters right;
    initialRow = builtins.genList (index: index) (builtins.length rightCharacters + 1);
    nextRow = previousRow: leftCharacter:
      builtins.foldl' (row: index: let
        insertion = builtins.elemAt row (index - 1) + 1;
        deletion = builtins.elemAt previousRow index + 1;
        substitution =
          builtins.elemAt previousRow (index - 1)
          + (
            if leftCharacter == builtins.elemAt rightCharacters (index - 1)
            then 0
            else 1
          );
        minimum =
          if insertion < deletion
          then insertion
          else deletion;
      in
        row
        ++ [
          (
            if minimum < substitution
            then minimum
            else substitution
          )
        ])
      [(builtins.head previousRow + 1)]
      (builtins.genList (index: index + 1) (builtins.length rightCharacters));
    finalRow = builtins.foldl' nextRow initialRow (lib.stringToCharacters left);
  in
    builtins.elemAt finalRow (builtins.length rightCharacters);

  closestOption = unknown: options:
    builtins.foldl' (closest: option: let
      candidateDistance = levenshtein unknown option;
    in
      if candidateDistance < closest.distance
      then {
        name = option;
        distance = candidateDistance;
      }
      else closest)
    {
      name = builtins.head options;
      distance = levenshtein unknown (builtins.head options);
    }
    (builtins.tail options);

  optionLabel = path: name:
    if path == ""
    then name
    else "${path}.${name}";

  ensureAttrs = path: value:
    if builtins.isAttrs value
    then value
    else throw "beam-overlay: `${path}` must be an attribute set.";

  ensureKeys = path: allowed: value: let
    attrs = ensureAttrs path value;
    unknown = builtins.filter (name: !(builtins.elem name allowed)) (builtins.attrNames attrs);
    suggestion =
      if allowed == []
      then null
      else (closestOption (builtins.head unknown) allowed).name;
    label = optionLabel path (builtins.head unknown);
    suggestionLabel =
      if suggestion == null
      then null
      else optionLabel path suggestion;
  in
    if unknown == []
    then attrs
    else
      throw (
        "beam-overlay: unknown option `${label}`."
        + (
          if suggestionLabel == null
          then ""
          else "\nDid you mean `${suggestionLabel}`?"
        )
      );

  section = path: defaults: value: let
    attrs = ensureKeys path (builtins.attrNames defaults) value;
  in
    lib.mapAttrs (name: default: attrs.${name} or default) defaults;

  boolean = path: value:
    if builtins.isBool value
    then value
    else throw "beam-overlay: `${path}` must be a boolean.";

  string = path: value:
    if builtins.isString value
    then value
    else throw "beam-overlay: `${path}` must be a string.";

  raw = ensureKeys "" ["elixir" "erlang-otp" "gleam" "tools" "extraPackages"] rawOptions;

  elixirOptions = section "elixir" {
    enable = true;
    version = "latest";
  } (raw.elixir or {});

  otpOptions = section "erlang-otp" {
    version = null;
    wxSupport = false;
  } (raw."erlang-otp" or {});

  gleamOptions = section "gleam" {
    enable = false;
    version = "latest";
  } (raw.gleam or {});

  rawTools = section "tools" {
    phx_new = {};
    igniter_new = {};
    livebook = {};
    tailwindcss = {};
    esbuild = {};
  } (raw.tools or {});

  phxNew =
    section "tools.phx_new" {
      enable = false;
      version = "latest";
    }
    rawTools.phx_new;

  igniterNew =
    section "tools.igniter_new" {
      enable = false;
      version = "latest";
    }
    rawTools.igniter_new;

  livebook =
    section "tools.livebook" {
      enable = false;
    }
    rawTools.livebook;

  tailwindcss =
    section "tools.tailwindcss" {
      enable = false;
      major = 4;
    }
    rawTools.tailwindcss;

  esbuild =
    section "tools.esbuild" {
      enable = false;
    }
    rawTools.esbuild;

  tools = {
    phx_new =
      phxNew
      // {
        enable = boolean "tools.phx_new.enable" phxNew.enable;
        version = string "tools.phx_new.version" phxNew.version;
      };
    igniter_new =
      igniterNew
      // {
        enable = boolean "tools.igniter_new.enable" igniterNew.enable;
        version = string "tools.igniter_new.version" igniterNew.version;
      };
    livebook =
      livebook
      // {
        enable = boolean "tools.livebook.enable" livebook.enable;
      };
    tailwindcss =
      tailwindcss
      // {
        enable = boolean "tools.tailwindcss.enable" tailwindcss.enable;
        major =
          if builtins.isInt tailwindcss.major && builtins.elem tailwindcss.major [3 4]
          then tailwindcss.major
          else throw "beam-overlay: `tools.tailwindcss.major` must be 3 or 4.";
      };
    esbuild =
      esbuild
      // {
        enable = boolean "tools.esbuild.enable" esbuild.enable;
      };
  };

  normalizedElixir =
    elixirOptions
    // {
      enable = boolean "elixir.enable" elixirOptions.enable;
      version = string "elixir.version" elixirOptions.version;
    };

  normalizedOtp =
    otpOptions
    // {
      version =
        if otpOptions.version == null
        then null
        else string "erlang-otp.version" otpOptions.version;
      wxSupport = boolean "erlang-otp.wxSupport" otpOptions.wxSupport;
    };

  normalizedGleam =
    gleamOptions
    // {
      enable = boolean "gleam.enable" gleamOptions.enable;
      version = string "gleam.version" gleamOptions.version;
    };

  extraPackages = raw.extraPackages or [];
in
  if !builtins.isList extraPackages
  then throw "beam-overlay: `extraPackages` must be a list."
  else if !normalizedElixir.enable && (tools.phx_new.enable || tools.igniter_new.enable)
  then throw "beam-overlay: Phoenix archives require `elixir.enable = true`."
  else {
    elixir = normalizedElixir;
    "erlang-otp" = normalizedOtp;
    gleam = normalizedGleam;
    inherit tools extraPackages;
  }
