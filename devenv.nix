{
  pkgs,
  lib,
  config,
  ...
}:
let
  postgresql = pkgs.postgresql_16.overrideAttrs {
    icuSupport = true;
    icu = pkgs.icu;
  };
in
{
  packages = [
    postgresql
    config.languages.python.package.pkgs.psycopg2
  ];

  languages.python = {
    enable = true;
    package = pkgs.python312;
    uv = {
      enable = true;
      sync = {
        enable = true;
        allExtras = true;
      };
    };
    venv.enable = true;
  };

  services.postgres.enable = true;
  services.postgres.package = pkgs.postgresql_16;
  services.postgres.extensions = ext: [ ext.timescaledb ];
  services.postgres.settings.log_min_messages = "NOTICE";
  services.postgres.settings.client_min_messages = "NOTICE";
  services.postgres.settings.log_min_error_statement = "NOTICE";
  services.postgres.settings.shared_preload_libraries = "timescaledb";
  services.postgres.initialScript = "CREATE ROLE postgres SUPERUSER;";

  enterShell = ''
    git --version
  '';

  scripts.reset.exec = ''
    rm -rf $DEVENV_STATE/postgres
  '';
  process.manager.before = ''reset'';

  enterTest =
    let
      pg_isready = lib.getExe' config.services.postgres.package "pg_isready";

    in
    ''
      echo "Running tests"
      timeout 30 bash -c "until ${pg_isready} -d template1 -q; do sleep 0.5; done"
      python -m pytest tests
    '';

  git-hooks.hooks = {
    actionlint.enable = true;
    ruff.enable = true;
    ruff-format.enable = true;
    check-toml.enable = true;
    deadnix.enable = true;
    nixfmt-rfc-style.enable = true;
    end-of-file-fixer.enable = true;
    markdownlint.enable = true;
    pyupgrade.enable = true;
    ripsecrets.enable = true;
    trufflehog.enable = true;
  };
}
