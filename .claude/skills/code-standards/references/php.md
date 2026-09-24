# PHP Standards

Verified: 2026-09-24

| Item | Version | Source |
| --- | --- | --- |
| PHP | 8.5 (current stable branch) | https://www.php.net/supported-versions.php |
| PER Coding Style | 3.1 (extends and replaces PSR-12, requires PSR-1) | https://www.php-fig.org/per/coding-style/ |
| PSR-4 Autoloading | final | https://www.php-fig.org/psr/psr-4/ |
| PHP-CS-Fixer | 3.95 (rule set `@PER-CS` tracks the latest PER-CS) | https://cs.symfony.com/doc/ruleSets/ |
| PHPStan | 2.2 (levels 0–10, `max` = highest) | https://phpstan.org/user-guide/rule-levels |
| PHPUnit | 13.3 | https://phpunit.de |
| Composer | 2.x | https://getcomposer.org/doc/ |

## Tooling

- Every tool is a `require-dev` Composer dependency, run via `vendor/bin/`. No global installs.

```bash
composer require --dev friendsofphp/php-cs-fixer phpstan/phpstan phpunit/phpunit
```

- **Formatter**: PHP-CS-Fixer with PER-CS. `.php-cs-fixer.dist.php` at the project root:

```php
<?php

declare(strict_types=1);

$finder = (new PhpCsFixer\Finder())
    ->in(__DIR__)
    ->exclude(['vendor', 'var', 'storage']);

return (new PhpCsFixer\Config())
    ->setRiskyAllowed(true)
    ->setRules([
        '@PER-CS' => true,
        '@PER-CS:risky' => true,
        'declare_strict_types' => true,
    ])
    ->setFinder($finder);
```

- **Static analysis**: PHPStan. New projects start at `level: max`. Legacy code starts at the
  highest level that passes and uses a baseline (`--generate-baseline`) to ratchet up.
  `phpstan.neon.dist`:

```yaml
parameters:
    level: max
    paths:
        - src
        - tests
```

- **Composer conventions**:
  - `composer.json` declares `"require": {"php": "^8.5"}` (or the project's minimum) and
    every used extension (`ext-pdo`, `ext-mbstring`, ...).
  - Commit `composer.lock`. Install with `composer install`; use `composer update` only to
    change dependencies deliberately.
  - Define scripts so commands are uniform:

```json
{
    "scripts": {
        "lint": "php-cs-fixer fix --dry-run --diff",
        "fix": "php-cs-fixer fix",
        "analyse": "phpstan analyse",
        "test": "phpunit"
    }
}
```

## Project Layout

- PSR-4: one class per file, namespace maps to directory, file name equals class name.

```json
{
    "autoload": {
        "psr-4": { "Vendor\\Project\\": "src/" }
    },
    "autoload-dev": {
        "psr-4": { "Vendor\\Project\\Tests\\": "tests/" }
    }
}
```

```text
composer.json
composer.lock
phpstan.neon.dist
phpunit.xml.dist
.php-cs-fixer.dist.php
public/        # web root: only index.php and static assets
src/           # Vendor\Project\...
tests/         # Vendor\Project\Tests\...
```

- The web server document root is `public/`, never the project root.
- Run `composer dump-autoload` after adding namespaces; never `require` class files manually.

## Naming

- PSR-1 / PER-CS: classes, interfaces, traits, enums in `PascalCase`; methods and properties
  in `camelCase`; class constants in `UPPER_SNAKE_CASE`; enum cases MUST be `PascalCase`
  (constants inside enums: `PascalCase` recommended).
- Acronyms are written as words (PER-CS recommends php-src style): `XmlFormatter`,
  `HttpClient`, not `XMLFormatter`.
- Methods are Action-Object: `fetchUser()`, `validateEmail()`, `parseHeader()`.
- Interfaces end in `Interface` only if the project already does so; otherwise use nouns.
- Every file starts with `<?php` then a blank line then `declare(strict_types=1);`.
- Type every parameter, return and property. Use `readonly` properties/classes for values.

## Security Specifics

- **SQL**: PDO or a query builder with bound parameters. Set
  `PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION` and `PDO::ATTR_EMULATE_PREPARES => false`.
- **Shell**: avoid shell calls. If unavoidable, `proc_open()` with an array command
  (no shell), or `escapeshellarg()` for every argument. Never `shell_exec`/backticks with input.
- **Paths**: `realpath()` the target, then check it starts with the allowed root plus
  `DIRECTORY_SEPARATOR`. Reject `false` results.
- **Output**: `htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')` or the
  template engine's auto-escaping (Twig, Blade). Never echo raw input.
- **Deserialization**: never `unserialize()` untrusted data; use `json_decode(..., flags:
  JSON_THROW_ON_ERROR)`.
- **Includes**: never `include`/`require` a path derived from input.
- **Passwords**: `password_hash()` / `password_verify()` only.
- **Randomness**: `random_bytes()` / `random_int()`, never `rand()`/`mt_rand()` for security.
- **Secrets**: `getenv()` / `$_ENV` loaded from `.env` (e.g. `vlucas/phpdotenv`), never in code.
- Disable `display_errors` in production; log instead.

## Testing

- PHPUnit 13 with attributes (`#[Test]`, `#[DataProvider]`), not docblock annotations.
- Test class `FooTest` in `tests/` mirrors `src/Foo`.
- Test names describe behavior in English: `testRejectsExpiredToken`.
- `phpunit.xml.dist` enables `failOnWarning`, `failOnRisky`, and `executionOrder="random"`.

## Checklist

- [ ] `declare(strict_types=1);` in every file; all types declared.
- [ ] Namespace and path match the PSR-4 mapping; `composer dump-autoload` clean.
- [ ] `vendor/bin/php-cs-fixer fix --dry-run --diff` reports nothing.
- [ ] `vendor/bin/phpstan analyse` passes at the configured level; no new baseline entries.
- [ ] `vendor/bin/phpunit` passes.
- [ ] No string-built SQL, no shell with input, paths checked against a root, output escaped.
- [ ] No secrets in code; new env vars added to `.env.example`.
- [ ] `composer.lock` committed when dependencies change.
