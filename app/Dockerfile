FROM node:20.20.0-alpine3.22@sha256:9a6da5b3b736cc5ccc3bc11312cb83d0dae84705f00da92ae420d76a15a9da6f AS build
WORKDIR /workspace
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:20.20.0-alpine3.22@sha256:9a6da5b3b736cc5ccc3bc11312cb83d0dae84705f00da92ae420d76a15a9da6f AS runtime
ENV NODE_ENV=production
WORKDIR /app
RUN addgroup -S app && adduser -S -G app -u 10001 app
COPY --from=build --chown=app:app /workspace/package.json ./package.json
COPY --from=build --chown=app:app /workspace/node_modules ./node_modules
COPY --from=build --chown=app:app /workspace/dist ./dist
USER 10001
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 CMD wget -qO- http://127.0.0.1:3000/healthz >/dev/null || exit 1
CMD ["node", "dist/index.js"]
