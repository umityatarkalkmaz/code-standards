# JavaScript / TypeScript Standards

Verified: 2026-10-12

| Item | Version | Source |
| --- | --- | --- |
| Node.js | 24.x Active LTS "Krypton" (26.x is Current, not LTS yet) | https://nodejs.org/en/about/previous-releases |
| TypeScript | 6.0.3 pinned (`~6.0`); 7.0.2 is latest but see note | https://www.typescriptlang.org/tsconfig |
| ESLint | 10.12 (flat config only; `.eslintrc*` removed) | https://eslint.org/docs/latest/use/configure/ |
| typescript-eslint | 8.71 (peer: `typescript >=4.8.4 <6.1.0`) | https://typescript-eslint.io |
| Prettier | 3.9 | https://prettier.io/docs/ |
| Next.js | 16.4 (App Router) | https://nextjs.org/docs/app |
| Tailwind CSS | 4.3 (CSS-first configuration) | https://tailwindcss.com/docs |
| Vitest | 5.0 | https://vitest.dev |

> **TypeScript 7 note**: TS 7 (native compiler) is the npm `latest`, but typescript-eslint
> 8.71 only supports `typescript <6.1.0`. Pin `typescript@~6.0` in any project that uses
> type-aware ESLint or Next.js. Move to TS 7 only after typescript-eslint's peer range
> includes it. TS 6+ already defaults to `strict: true` and `module: esnext`; still set them
> explicitly so intent survives default changes.

## Tooling

- Package manager: npm by default (lockfile `package-lock.json`, install with `npm ci`).
  If the project already uses pnpm or yarn, keep it. Never mix lockfiles.
- `package.json` sets `"type": "module"` and `"engines": { "node": ">=24" }`.
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

- Prettier: with Tailwind, add `prettier-plugin-tailwindcss` to sort classes.

## Project Layout

- **ES Modules only** in new code: `import`/`export`, `"type": "module"`. No `require`,
  `module.exports` or `__dirname` (use `import.meta.dirname` / `import.meta.filename`).
  `.cjs` only for a third-party config that cannot load ESM. Expo / React Native apps keep ESM
  syntax in source but do not set `"type": "module"`; see [react-native.md](react-native.md).
- Use the `node:` prefix for built-ins: `import { readFile } from "node:fs/promises";`.
- Next.js: modules under `lib/server/` import `server-only`.
- **Tailwind CSS 4**: configure in CSS, not `tailwind.config.js`:

```css
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.62 0.19 250);
}
```

  - Use utility classes in markup; extract a component, not an `@apply` class, for reuse.
  - Merge conditional classes with a small helper (`clsx` + `tailwind-merge`).

## Naming

- File names: `kebab-case.ts` for modules; React components `PascalCase.tsx` or the project's
  existing convention; Next.js reserved files keep their names (`page.tsx`, `route.ts`).
- Prefer `type` aliases for unions/objects; `interface` when declaration merging is intended.

## Security Specifics

- Parse every external input with a schema (`zod`, `valibot`) at the boundary; validate env at
  startup the same way.
- Unavoidable HTML: sanitize with DOMPurify before `dangerouslySetInnerHTML`/`innerHTML`.
- Processes: `execFile`/`spawn` with an argument array and `shell: false`.
- Paths: `path.resolve(root, input)`, then verify `resolved.startsWith(root + path.sep)`.
- Dynamic keys: `Map` or `Object.create(null)`; reject `__proto__`, `constructor`, `prototype`.

## Testing

- Vitest (`*.test.ts` next to the source or under `tests/`); Playwright for end-to-end.

## Checklist

- [ ] `npx tsc --noEmit` passes with `strict` and the extra strict flags.
- [ ] `npx vitest run` passes.
