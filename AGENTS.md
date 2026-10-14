# thenotemaker/iframely – notes for coding agents

Fork of itteco/iframely used by NoteMaker as an optional sidecar. Read `docs/THENOTEMAKER.md` first: it lists exactly what differs from upstream, the environment switches, the release procedure and the Docker Hub OIDC requirements.

- Keep the delta from upstream small so `git merge upstream/dev` stays easy. Fork-only code is marked "thenotemaker fork" or lives in `scripts/`, `whitelist-bundled/`, `docs/THENOTEMAKER.md` and the three workflows.
- `corepack pnpm test` and `corepack pnpm audit --prod` must both be clean before committing. Do not bump `package.json`'s version (it is upstream's).
- The default branch is `dev`. Images are published only from a `vX.Y.Z` tag via `.github/workflows/release.yml`; nothing builds on a branch push. A manual run on a branch is a dry run.
- `whitelist/` must stay empty (a `iframely-*.json` there switches off downloading for everyone); the bundled list is in `whitelist-bundled/` and is selected with `IFRAMELY_WHITELIST=bundled`.
