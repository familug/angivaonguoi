# ---- Build stage ----
FROM docker.io/hexpm/elixir:1.18-erlang-27.3.4.9-debian-bookworm-20260223-slim AS builder

# Only C compiler + git: C for bcrypt NIF, git for heroicons sparse checkout dep
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Fetch deps — separate layer so it's cached unless mix.exs/mix.lock change
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Compile-time and runtime config
COPY config/config.exs config/prod.exs config/runtime.exs config/

# Compile deps (separate cached layer)
RUN mix deps.compile

# Copy source
COPY priv/ priv/
COPY lib/ lib/
COPY assets/ assets/

# Compile app first — generates _build/prod/phoenix-colocated/ needed by esbuild
RUN mix compile

# Download esbuild/tailwind binaries and compile assets
RUN mix assets.deploy

# Build release
RUN mix release

# ---- Runtime stage ----
FROM docker.io/debian:bookworm-slim AS runtime

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV PHX_SERVER=true

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/angivaonguoi ./

VOLUME ["/app/lib/angivaonguoi-0.1.0/priv/static/uploads"]

EXPOSE 4000

CMD ["bin/angivaonguoi", "start"]
