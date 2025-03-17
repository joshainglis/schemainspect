{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  psycopg2,
  pymysql,
  sqlalchemy,
  six,
  flask,
  pendulum,
  packaging,
  hatchling,
  pytestCheckHook,
  pytest-xdist,
  pytest-sugar,
  postgresql,
  postgresqlTestHook,
}:
buildPythonPackage rec {
  pname = "sqlbag";
  version = "0.2.0";
  format = "pyproject";

  doCheck = true;

  src = fetchFromGitHub {
    owner = "joshainglis";
    repo = "sqlbag";
    rev = "6e9a5e8f176968b83c7756b95ef475ef8c3163af";
    hash = "sha256-KVyS4pUPsNeLAuJDz5iuP00jGhN+N31XIuOwh2bUXNw=";
  };

  nativeBuildInputs = [ hatchling ];

  propagatedBuildInputs = [
    sqlalchemy
    six
    packaging
    flask
    pendulum

    psycopg2
    pymysql
  ];

  nativeCheckInputs = [
    pytestCheckHook
    pytest-xdist
    pytest-sugar

    postgresql
    postgresqlTestHook

    flask
    pendulum
  ];

  preCheck = ''
    export postgresqlTestUserOptions="LOGIN SUPERUSER"
  '';

  pytestFlagsArray = [
    "-x"
    "-svv"
    "tests"
  ];

  pythonImportsCheck = [ "sqlbag" ];

  meta = with lib; {
    description = "Handy python code for doing database things";
    homepage = "https://github.com/djrobstep/sqlbag";
    license = with licenses; [ unlicense ];
    maintainers = with maintainers; [ bpeetz ];
  };
}
