# Python Standards

Verified: 2026-09-24

| Item | Version | Source |
| --- | --- | --- |
| Python | 3.14 | https://www.python.org/downloads/ |
| ruff (lint + format) | 0.16.9 | https://docs.astral.sh/ruff/ |
| uv (env + dependencies) | 0.12 | https://docs.astral.sh/uv/ |
| mypy | 2.3 | https://mypy.readthedocs.io |
| pytest | 9.1 | https://docs.pytest.org |
| `pyproject.toml` metadata | PEP 621 / packaging guide | https://packaging.python.org/en/latest/guides/writing-pyproject-toml/ |

## Tooling

- **Virtual environment per project** in `.venv/` (gitignored). Never `pip install` into the
  system or user site-packages; never `sudo pip`.
- uv manages Python, the venv and the lockfile. Install uv itself per the uv docs if missing;
  then everything else is project-scoped:

```bash
uv init --package      # new project with src/ layout
uv add httpx           # runtime dependency
uv add --dev ruff mypy pytest
uv run pytest          # always run tools through the venv
```

  Without uv: `python3 -m venv .venv` and `.venv/bin/pip install -e '.[dev]'`.
- `pyproject.toml` is the single config file:

```toml
[project]
name = "project-name"
version = "0.1.0"
requires-python = ">=3.14"
dependencies = []

[dependency-groups]
dev = ["ruff", "mypy", "pytest"]

[tool.ruff]
target-version = "py314"
line-length = 88
src = ["src", "tests"]

[tool.ruff.lint]
select = [
  "E", "W", "F",   # pycodestyle, pyflakes
  "I",             # isort
  "N",             # pep8-naming
  "UP",            # pyupgrade
  "B",             # bugbear
  "S",             # bandit (security)
  "SIM", "C4", "RET", "PTH",
  "ANN",           # type annotations present
  "RUF",
]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101"]   # assert is fine in tests

[tool.mypy]
strict = true
python_version = "3.14"

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["--strict-markers", "--strict-config"]
```

- Commands: `uv run ruff format`, `uv run ruff check`, `uv run mypy src`, `uv run pytest`.
- Commit `uv.lock`.

## Project Layout

```text
pyproject.toml
uv.lock
.python-version
src/
  project_name/
    __init__.py
    __main__.py      # optional CLI entry
    py.typed         # if the package is typed and published
tests/
  test_<module>.py
```

- `src/` layout prevents importing the working tree by accident.
- Entry points via `[project.scripts]`, not ad-hoc scripts on `PATH`.

## Naming

- PEP 8: `snake_case` for functions, variables, modules; `PascalCase` for classes;
  `UPPER_SNAKE_CASE` for constants; `_leading_underscore` for internal names.
- Functions are Action-Object: `fetch_user`, `validate_input`, `parse_config`.
- Type hints on every function signature and public attribute; use built-in generics
  (`list[str]`, `dict[str, int]`), `X | None`, `typing.Self`, `type` aliases (`type UserId = int`).
- Avoid `Any`; prefer `Protocol`, `TypedDict`, `dataclass(frozen=True, slots=True)`.

## Security Specifics

- **Validation**: parse external data into typed models (`pydantic`, `attrs` + validators,
  or dataclasses with explicit checks) at the boundary.
- **SQL**: DB-API parameters (`cursor.execute("... WHERE id = %s", (user_id,))`) or an ORM;
  never f-strings or `%` formatting into SQL.
- **Shell**: `subprocess.run([...], shell=False, check=True)`; never `os.system` or
  `shell=True` with input.
- **Paths**: `(root / name).resolve()` then `resolved.is_relative_to(root.resolve())`.
- **Deserialization**: never `pickle`/`marshal`/`shelve` untrusted data; `yaml.safe_load` only;
  `json` for interchange.
- **Code execution**: never `eval`/`exec` on input.
- **Templates**: Jinja2 with `autoescape=True` (or the framework default).
- **Randomness**: `secrets` module for tokens, never `random`.
- **Secrets**: `os.environ[...]` (or `pydantic-settings`) validated at startup; never log them.
- **HTTP**: always set timeouts on requests (`httpx`/`requests`), verify TLS (default on).

## Testing

- pytest; files `tests/test_<module>.py`, functions `test_<behavior>`:
  `test_rejects_expired_token`.
- Fixtures over setup classes; `pytest.mark.parametrize` for tables.
- No network in unit tests; mock at the boundary.

## Checklist

- [ ] Work inside the project `.venv` (uv); no global/system installs.
- [ ] `uv run ruff format --check` and `uv run ruff check` clean.
- [ ] `uv run mypy src` passes in strict mode; all signatures annotated.
- [ ] `uv run pytest` passes.
- [ ] No string-built SQL, no `shell=True`, no `pickle`/`eval` on input, paths confined to root.
- [ ] `pyproject.toml` is the only config; `uv.lock` committed; new env vars in `.env.example`.
