# thenotemaker/iframely: what this fork changes

This is a fork of [itteco/iframely](https://github.com/itteco/iframely) (MIT) that NoteMaker uses as its optional link-resolver sidecar. The engine is unchanged; the fork adds environment switches, a bundled domain list for installs without internet access, a hardened image and its own release pipeline. Everything is small on purpose so that upstream can be merged in without conflicts.

The default branch is `dev`, as upstream. Do not make changes to plugins here unless NoteMaker needs them; keep them in separate commits so they are easy to offer upstream.

## What differs from upstream

| Area | Change |
| --- | --- |
| `config.js` | Environment overrides (below), applied after `config.*.js` files. |
| `cluster.js` | `workersCount` comes from `IFRAMELY_WORKERS_COUNT`; the default stays one per CPU. |
| `whitelist-bundled/` | A committed copy of iframely.com's domain list, used only with `IFRAMELY_WHITELIST=bundled`. |
| `scripts/update-whitelist.mjs` | Downloads the list again (see "Monthly whitelist refresh"). |
| `Dockerfile` | OCI labels, npm removed from the final image, a `HEALTHCHECK` on `/health_check`. |
| `.github/workflows/` | `release.yml` (own pipeline), `update-whitelist.yml`, `tests.yml` (pull requests only). Upstream's npm publish and GHCR workflows are removed. |
| `pnpm-lock.yaml` | Refreshed so the `js-yaml` override resolves (`pnpm audit --prod` is clean). |

## Environment variables

All optional. With none set the container behaves like upstream.

| Variable | Meaning |
| --- | --- |
| `IFRAMELY_WHITELIST` | Unset or `download`: the domain list is fetched from iframely.com at start and every hour (upstream behaviour). `bundled`: use `whitelist-bundled/`, never contact iframely.com. Anything else stops the start. |
| `IFRAMELY_WHITELIST_URL` | Fetch the list from this address instead (a mirror). |
| `REDIS_URL` | Use Redis for the cache (`redis://host:6379`). Without it each process keeps its own in-memory cache. |
| `IFRAMELY_CACHE_TTL` | Cache lifetime in seconds. |
| `IFRAMELY_WORKERS_COUNT` | Worker processes. Default is the number of CPUs the container sees. |
| `IFRAMELY_USER_AGENT` | Replaces `Iframely/<version> (+...)`. Some sites allow-list crawlers by name (IMDb accepts `Iframely`), so change it only on purpose. |
| `NODE_ENV` | As upstream: `config.<NODE_ENV>.js` is read when it exists. |

The image listens on 8061: `GET /iframely?url=<address>` is the API, `GET /health_check` the probe.

## Whitelist: download by default, bundled for air-gapped installs

Iframely only knows how to read many sites (YouTube, Spotify, X, IMDb and so on) through the domain list. By default the server downloads it from iframely.com, and Iframely QA updates it daily, so a default install gets fixes without a new image. That is a call from your server to iframely.com at start and hourly. The address of the pages being previewed is not sent.

A server that cannot reach iframely.com sets `IFRAMELY_WHITELIST=bundled`. The list in the image is then as old as the release, so a release is cut after each monthly refresh.

How the switch works: the loader (`lib/whitelist.js`) downloads only when no file matching `iframely-*.json` is found in `WHITELIST_DIR`. The bundled list therefore lives in its own folder (`whitelist-bundled/`) and the mode points `WHITELIST_DIR` there and empties `WHITELIST_URL`. The folder is deliberately not `whitelist/`, where a file would switch downloading off for everyone.

The file keeps Itteco's own header (`"(c) 2026 Itteco Software Corp."` and a link to the format). Keep it when refreshing; the script writes the download unchanged.

## Monthly whitelist refresh

`update-whitelist.yml` runs on the 1st of each month (and by hand) and opens a pull request when the list changed. Merge it, then tag a release if bundled installs should get the new list. By hand:

    node scripts/update-whitelist.mjs      # rewrites whitelist-bundled/iframely-domains.json, prints old -> new domain count
    git commit -am "Refresh bundled whitelist" && git push

The script refuses a download with fewer than 1,000 domains (it has about 1,900), so a truncated response never replaces the file.

The workflow needs "Allow GitHub Actions to create and approve pull requests" on in the organization and in this repository (Settings → Actions → General). Without it the branch is pushed and the pull request has to be opened by hand.

## Releasing

Images are built only when asked, never on a push to a branch.

1. Merge what should ship into `dev`.
2. Tag the commit: `git tag -a v1.2.3 -m "v1.2.3" && git push origin v1.2.3`. Versions are plain semver for the fork. The upstream version it is based on (`package.json`) is recorded in the image label `io.thenotemaker.iframely.upstream-version`.
3. `release.yml` builds `linux/amd64`, smoke-tests it (see below), logs in to Docker Hub and pushes `thenotemaker/iframely:1.2.3`, `:1.2` and `:latest`. `linux/arm64` is opt-in: run the workflow by hand on the tag with the `arm64` box ticked, or set the repository variable `RELEASE_ARM64=true`.

Running the workflow by hand on a **branch** is a dry run: it builds and smoke-tests the image and pushes nothing, so it can be used before any Docker Hub setup exists.

The smoke test starts the image twice: once in the default mode (the log must show the list loaded from iframely.com and `example.com` must resolve to "Example Domain"), and once with `IFRAMELY_WHITELIST=bundled` (the list must be activated and iframely.com must not be contacted). It also checks that npm is gone and that the container does not run as root.

### Docker Hub trust (OIDC, no stored password)

Login uses the same mechanism as `thenotemaker/notemaker`. Once per repository:

1. Create the Docker Hub repository `thenotemaker/iframely`.
2. In Docker Home → Identity & auth → OIDC connections, add this repository's `v*.*.*` tags (read & write on `thenotemaker/iframely`) to the connection. Because only tags publish, the branch is not needed.
3. Make the organization secret `DOCKERHUB_OIDC_CONNECTION_ID` available to this repository (organization Settings → Secrets and variables → Actions → repository access).

If the login step answers `access_denied`, compare the `sub` printed by the "Show the OIDC claims" step with the subject in the connection (it looks like `repo:thenotemaker/iframely:ref:refs/tags/v1.2.3`).

## Staying close to upstream

    git remote add upstream https://github.com/itteco/iframely.git   # once
    git fetch upstream
    git merge upstream/dev

Conflicts are likely only in `config.js` (our block sits just before `config.baseStaticUrl` is computed), `cluster.js` (one line), the `Dockerfile` and `.gitignore`. After a merge run `pnpm install`, `pnpm test`, `pnpm audit --prod`, and a dry-run release. Bump nothing in `package.json`: its version is upstream's.

## Running it locally

    docker run --rm -p 8061:8061 thenotemaker/iframely
    curl 'http://localhost:8061/iframely?url=https://www.imdb.com/title/tt0374546/'

Without Docker: `corepack pnpm install && cp config.local.js.SAMPLE config.local.js && node cluster.js`.

## Running it safely

The service fetches whatever address it is given. Put it on a private network, let only the application call it (it has no authentication), and limit its outbound traffic to the public internet. The application should check an address (http/https only, no private ranges) before sending it here.
