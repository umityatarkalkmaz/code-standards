# Python Standards

Verified: 2026-10-12

| Item | Version | Source |
| --- | --- | --- |
| Python | 3.14 | https://www.python.org/downloads/ |
| ruff (lint + format) | 0.17.0 | https://docs.astral.sh/ruff/ |
| uv (env + dependencies) | 0.13 | https://docs.astral.sh/uv/ |
| mypy | 2.4 | https://mypy.readthedocs.io |
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

## Project Layout

- `src/` layout (`src/<project_name>/`), tests in `tests/`.
- Entry points via `[project.scripts]`, not ad-hoc scripts on `PATH`.

## Naming

No rules beyond the core rules.

## Security Specifics

- Parse external data into typed models (`pydantic`, or `attrs` with validators) at the
  boundary; settings via `pydantic-settings`, validated at startup.
- SQL via DB-API parameters (`cursor.execute("... WHERE id = %s", (user_id,))`) or an ORM.
- Paths: `(root / name).resolve()`, then `resolved.is_relative_to(root.resolve())`.

## Testing

No rules beyond the core rules.

## Checklist

- [ ] `uv run mypy src` passes in strict mode.
- [ ] `uv run pytest` passes.
- [ ] `pyproject.toml` is the only config file.
