{pkgs}:
pkgs.runCommand "beam-runtime-fixture" {} ''
  mkdir -p "$out/bin"
  cat > "$out/bin/server" <<EOF
  #!${pkgs.runtimeShell}
  echo beam-runtime-fixture
  EOF
  cat > "$out/bin/migrate" <<EOF
  #!${pkgs.runtimeShell}
  echo beam-runtime-migration
  EOF
  chmod +x "$out/bin/server" "$out/bin/migrate"
''
