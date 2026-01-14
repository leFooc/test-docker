### Optimized version 
ARG BUILD_SOURCE=builder
ARG ENV=production

### Base 
FROM node:23-alpine AS base
RUN apk add --no-cache curl 

FROM node:23-alpine AS base_build
RUN apk add --no-cache git openssh-client bash 

### Dependencies
FROM base_build AS dependencies 
WORKDIR /app 
COPY package.json yarn.lock ./
RUN --mount=type=ssh \
    --mount=type=bind,source=scripts/submodule.sh,target=/app/scripts/submodule.sh \
    --mount=type=bind,source=.gitmodules,target=/app/.gitmodules \
    --mount=type=bind,source=.git,target=/app/.git,rw=true \
    ### Add github to known hosts
    mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    ### Git clone submodule 
    git submodule update --init --recursive && \
    ### Install dependencies 
    yarn install --frozen-lockfile 
    
### Builder
FROM dependencies AS builder_ci_optimized
ARG ENV
WORKDIR /app
COPY . .
RUN case "$ENV" in \
      "development") cp .env.development .env.production ;; \
      "staging" )    cp .env.staging .env.production ;; \
    esac

RUN --mount=type=bind,from=next-cache,target=/app/.next/cache,rw=true \
    echo $ENV && \
    yarn build && \
    mkdir -p /app/output_cache && \
    cp -R .next/cache/* /app/output_cache/ 

FROM dependencies AS builder 
ARG ENV
WORKDIR /app 
COPY . .
RUN case "$ENV" in \
      "development") cp .env.development .env.production ;; \
      "staging" )    cp .env.staging .env.production ;; \
    esac
RUN echo $ENV && yarn build

FROM ${BUILD_SOURCE} AS abstract_builder 

### Runner 
FROM base AS runner 
ARG BUILD_SOURCE
ENV HOSTNAME=0.0.0.0 
WORKDIR /app 
COPY --chmod=755 --from=abstract_builder /app/.next/standalone/ .
COPY --chmod=755 --from=abstract_builder /app/.next/static ./.next/static
COPY --chmod=755 public/ ./public/
USER node 
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD curl -f http://127.0.0.1:3000/api/health || exit 1 
EXPOSE 3000 
CMD ["node", "/app/server.js"]

### Post CI cache export 
FROM scratch AS export_cache
COPY --from=builder_ci_optimized /app/output_cache /

