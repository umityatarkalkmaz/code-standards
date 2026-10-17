# PHP Standards

Verified: 2026-10-12

| Item | Version | Source |
| --- | --- | --- |
| PHP | 8.5 (current stable branch) | https://www.php.net/supported-versions.php |
| PER Coding Style | 3.1 (extends and replaces PSR-12, requires PSR-1) | https://www.php-fig.org/per/coding-style/ |
| PSR-4 Autoloading | final | https://www.php-fig.org/psr/psr-4/ |
| PHP-CS-Fixer | 3.95.27 (`@PER-CS` currently = `@PER-CS3x0`; no 3.1 set yet) | https://cs.symfony.com/doc/ruleSets/ |
| PHPStan | 2.3 (levels 0–10, `max` = highest) | https://phpstan.org/user-guide/rule-levels |
| PHPUnit | 13.4 | https://phpunit.de |
| Composer | 2.x | https://getcomposer.org/doc/ |

## Tooling

- Every tool is a `require-dev` Composer dependency, run via `vendor/bin/`. No global installs.
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

- **PER-CS 3.1 additions not yet automated**: `@PER-CS` in PHP-CS-Fixer 3.95 still maps to
  PER-CS 3.0. Apply the 3.1 rules by hand
  ([migration-3.1](https://github.com/php-fig/per-coding-style/blob/master/migration-3.1.md)):
  - `clone` is always called with parentheses: `clone($a)`.
  - `case` bodies are never wrapped in `{}`; every non-empty `case` ends with `break`,
    `return` or similar, including the last one; multi-line `case` conditions are wrapped in
    parentheses (`case (` … `):`).
  - The pipe operator `|>` has a space on both sides; in multi-line chains each line starts
    with `|>` and is indented.
  - Empty closures are written `function () {}` on one line; prefer `fn() => null`.
  - Attributes on anonymous classes start on the line after `new`, indented once.
  - Non-public enum constants are `private`, not `protected`.
  - The opening bracket of a multi-line array never sits on its own line, in any context.

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

  Every listed path must exist, or a full `phpstan analyse` fails; add `tests` once the
  directory is created.

- **Composer scripts** so commands are uniform:

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

- PSR-4: `src/` → `Vendor\Project\`, `tests/` → `Vendor\Project\Tests\`.
- The web server document root is `public/`, never the project root.

## Naming

- Acronyms are written as words (PER-CS recommends php-src style): `XmlFormatter`,
  `HttpClient`, not `XMLFormatter`.
- Interfaces end in `Interface` only if the project already does so; otherwise use nouns.
- Every file starts with `<?php` then a blank line then `declare(strict_types=1);`.
- Use `readonly` properties/classes for values.

## Security Specifics

- PDO with `PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION` and
  `PDO::ATTR_EMULATE_PREPARES => false`.
- Process calls: `proc_open()` with an array command; otherwise `escapeshellarg()` per argument.
- Paths: `realpath()`, then check the allowed root plus `DIRECTORY_SEPARATOR`; reject `false`.
- Output: `htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')` or template
  auto-escaping (Twig, Blade).
- `json_decode(..., flags: JSON_THROW_ON_ERROR)` instead of `unserialize()`.
- `password_hash()` / `password_verify()`; `random_bytes()` / `random_int()`.
- Secrets via `getenv()` / `$_ENV` loaded with `vlucas/phpdotenv`.

## Testing

- PHPUnit 13 with attributes (`#[Test]`, `#[DataProvider]`), not docblock annotations.
- `phpunit.xml.dist` enables `failOnWarning`, `failOnRisky`, and `executionOrder="random"`.

## Checklist

- [ ] PER-CS 3.1 manual rules applied.
- [ ] `vendor/bin/phpunit` passes.
