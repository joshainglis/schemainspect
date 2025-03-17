{
  pkgs,
  lib,
  config,
  ...
}:
let
  postgresql = pkgs.postgresql_16;
  python = pkgs.python312;
  sqlbag = python.pkgs.callPackage ./nix/dependencies/sqlbag.nix { };
  schemainspect = python.pkgs.callPackage ./package.nix { inherit sqlbag; };
in
{
  packages = [
    pkgs.git
    postgresql
    python
    schemainspect
    config.languages.python.package.pkgs.psycopg2
    config.languages.python.package.pkgs.sqlalchemy
    config.languages.python.package.pkgs.pytest
    config.languages.python.package.pkgs.pytest-cov
    config.languages.python.package.pkgs.packaging
    config.languages.python.package.pkgs.hatchling
    config.languages.python.package.pkgs.uv
  ];

  languages.python = {
    enable = true;
    package = pkgs.python312;
  };

  services.postgres.enable = true;
  services.postgres.package = postgresql;
  services.postgres.listen_addresses = "127.0.0.1";
  services.postgres.extensions = ext: [ ext.timescaledb ];
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
