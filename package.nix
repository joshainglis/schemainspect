{
  lib,
  buildPythonPackage,
  psycopg2,
  sqlalchemy,
  sqlbag,
  packaging,
  hatchling,
  pytestCheckHook,
  pytest,
  pytest-cov,
  postgresql,
  postgresqlTestHook,
}:
buildPythonPackage {
  pname = "schemainspect";
  version = "4.0.0";
  format = "pyproject";

  doCheck = false;

  src = ./.;

  nativeBuildInputs = [ hatchling ];

  propagatedBuildInputs = [
    sqlalchemy
    packaging
    sqlbag

    psycopg2
  ];

  nativeCheckInputs = [
    pytestCheckHook

    pytest
    pytest-cov

    postgresql
    postgresqlTestHook
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
    homepage = "https://github.com/djrobstep/schemainspect";
    license = with licenses; [ unlicense ];
    maintainers = with maintainers; [ bpeetz ];
  };
}
