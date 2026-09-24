# JavaScript / TypeScript Standards

Verified: 2026-09-24

| Item | Version | Source |
| --- | --- | --- |
| Node.js | 24.x Active LTS "Krypton" (26.x is Current, not LTS yet) | https://nodejs.org/en/about/previous-releases |
| TypeScript | 6.0.3 pinned (`~6.0`); 7.0.2 is latest but see note | https://www.typescriptlang.org/tsconfig |
| ESLint | 10.11 (flat config only; `.eslintrc*` removed) | https://eslint.org/docs/latest/use/configure/ |
| typescript-eslint | 8.70 (peer: `typescript >=4.8.4 <6.1.0`) | https://typescript-eslint.io |
| Prettier | 3.9 | https://prettier.io/docs/ |
| Next.js | 16.3 (App Router) | https://nextjs.org/docs/app |
| Tailwind CSS | 4.3 (CSS-first configuration) | https://tailwindcss.com/docs |
| Vitest | 5.0 | https://vitest.dev |

> **TypeScript 7 note**: TS 7 (native compiler) is the npm `latest`, but typescript-eslint
> 8.70 only supports `typescript <6.1.0`. Pin `typescript@~6.0` in any project that uses
> type-aware ESLint or Next.js. Move to TS 7 only after typescript-eslint's peer range
> includes it. TS 6+ already defaults to `strict: true` and `module: esnext`; still set them
> explicitly so intent survives default changes.

## Tooling

- Package manager: npm by default (lockfile `package-lock.json`, install with `npm ci`).
  If the project already uses pnpm or yarn, keep it. Never mix lockfiles.
- All tools are `devDependencies`, run with `npx` or `npm run`. No global installs.

```bash
npm install --save-dev typescript@~6.0 eslint @eslint/js typescript-eslint prettier vitest @types/node
```

- `package.json` essentials:

```json
{
  "type": "module",
  "engines": { "node": ">=24" },
  "scripts": {
    "lint": "eslint .",
    "format": "prettier --write .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  }
}
```

- `tsconfig.json` (library / Node service; Next.js generates its own, then add the strict flags):

```json
{
  "compilerOptions": {
    "target": "es2024",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,
    "isolatedModules": true,
    "skipLibCheck": true,
    "outDir": "dist"
  },
  "include": ["src", "tests"]
}
```

  For bundler-driven apps (Next.js, Vite) use `"module": "esnext"` + `"moduleResolution": "bundler"`.

- `eslint.config.js` (flat config, ESM):

```js
import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig(
  { ignores: ["dist/", ".next/", "coverage/", "node_modules/"] },
  js.configs.recommended,
  tseslint.configs.strictTypeChecked,
  tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
  },
);
```

  Next.js projects add `eslint-config-next` (flat export) instead of hand-rolling React rules.

- Prettier: default options; a `.prettierrc.json` only for deliberate deviations. With
  Tailwind, add `prettier-plugin-tailwindcss` to sort classes.

## Project Layout

- **ES Modules only** in new code: `import`/`export`, `"type": "module"`. No `require`,
  `module.exports` or `__dirname` (use `import.meta.dirname` / `import.meta.filename`).
  `.cjs` only for a third-party config that cannot load ESM.
- Use the `node:` prefix for built-ins: `import { readFile } from "node:fs/promises";`.
- Node service / library:

```text
package.json
package-lock.json
tsconfig.json
eslint.config.js
src/
  index.ts
tests/
```

- **Next.js App Router**:

```text
app/
  layout.tsx          # root layout
  page.tsx            # route UI
  loading.tsx  error.tsx  not-found.tsx
  (group)/            # route groups, no URL segment
  api/<name>/route.ts # route handlers
components/           # shared UI
lib/                  # server/client utilities (lib/server/* imports "server-only")
public/
```

  - Components are Server Components by default. Add `"use client"` only to leaf components
    that need state, effects or browser APIs.
  - Fetch data in Server Components or route handlers, not in client effects.
  - Server Actions (`"use server"`) are public endpoints: validate input (e.g. `zod`) and
    check authorization inside every action.
  - Import `server-only` in modules that touch secrets or the database.
  - Only `NEXT_PUBLIC_*` env vars reach the browser; never put secrets there.
- **Tailwind CSS 4**: configure in CSS, not `tailwind.config.js`:

```css
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.62 0.19 250);
}
```

  - Use utility classes in markup; extract a component, not an `@apply` class, for reuse.
  - Never build class names dynamically (`` `text-${color}-500` ``); map to full literal
    class strings so the scanner can see them.
  - Merge conditional classes with a small helper (`clsx` + `tailwind-merge`).

## Naming

- `camelCase` for variables and functions, `PascalCase` for types, classes and React
  components, `UPPER_SNAKE_CASE` for true constants.
- Functions are Action-Object: `fetchUser`, `validateInput`, `parseQuery`.
- File names: `kebab-case.ts` for modules; React components `PascalCase.tsx` or the project's
  existing convention; Next.js reserved files keep their names (`page.tsx`, `route.ts`).
- Prefer `type` aliases for unions/objects; `interface` when declaration merging is intended.
- No `any`; use `unknown` and narrow. No non-null assertions (`!`) without a comment.

## Security Specifics

- **Validation**: parse every external input with a schema (`zod`, `valibot`) at the boundary;
  work with the parsed type afterwards.
- **XSS**: rely on JSX escaping. No `dangerouslySetInnerHTML`/`innerHTML` with untrusted data;
  if HTML is unavoidable, sanitize with DOMPurify first.
- **Shell**: `execFile`/`spawn` with an argument array and `shell: false`. Never `exec` with
  interpolated input.
- **Paths**: `path.resolve(root, input)` then verify `resolved.startsWith(root + path.sep)`.
- **SQL**: parameterized queries or a query builder/ORM; no template-string SQL with input.
- **Prototype pollution**: never merge untrusted objects into plain objects; use `Map` or
  `Object.create(null)` for dynamic keys; reject `__proto__`, `constructor`, `prototype`.
- **Secrets**: `process.env` only on the server; validate env at startup with a schema.
- **Dependencies**: `npm audit` on dependency changes; no install scripts from unknown packages.
- Set security headers (CSP, `X-Content-Type-Options`, `Referrer-Policy`) in middleware or config.

## Testing

- Vitest (`*.test.ts` next to the source or under `tests/`); Playwright for end-to-end.
- Test names describe behavior in English: `it("rejects an expired token", ...)`.
- No network in unit tests; mock at the boundary.

## Checklist

- [ ] ESM only; no `require`/`module.exports` in new code; `node:` prefix for built-ins.
- [ ] `npx tsc --noEmit` passes with `strict` and the extra strict flags.
- [ ] `npx eslint .` and `npx prettier --check .` pass.
- [ ] `npx vitest run` passes.
- [ ] Next.js: `"use client"` only where needed; Server Actions validate input and authz;
      secrets only in server-only modules.
- [ ] Tailwind: no dynamically built class names; theme in CSS `@theme`.
- [ ] External input schema-validated; no raw HTML, shell strings or string-built SQL.
- [ ] Lockfile committed; new env vars added to `.env.example`.
