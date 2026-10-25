FROM node:24-alpine

# thenotemaker fork. The release workflow passes the real values (docs/THENOTEMAKER.md).
ARG VERSION=dev
ARG REVISION=unknown
LABEL org.opencontainers.image.title="iframely" \
      org.opencontainers.image.description="Self-hosted link metadata and embed service (fork of itteco/iframely)" \
      org.opencontainers.image.source="https://github.com/thenotemaker/iframely" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}"

EXPOSE 8061

WORKDIR /iframely

# Create new non-root user
RUN addgroup --system iframelygroup && adduser --system iframely -G iframelygroup
RUN apk add g++ make python3

# This will change the config to `config.<VALUE>.js` and the express server to change its behaviour.
# You should overwrite this on the CLI with `-e NODE_ENV=production`.
ENV NODE_ENV=local

RUN corepack enable

## Utilize docker layer cache
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml /iframely/
COPY patches/ /iframely/patches/
RUN pnpm install --frozen-lockfile --prod

COPY . /iframely

RUN chown -R iframely /iframely/config.local.js || touch /iframely/config.local.js

# Nothing at runtime needs a package manager; leaving npm out also drops its bundled dependencies from the image.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

USER iframely

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8061/health_check').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"

ENTRYPOINT [ "/iframely/docker/entrypoint.sh" ]
