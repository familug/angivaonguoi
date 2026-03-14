# ---- Build stage ----
FROM docker.io/hexpm/elixir:1.18-erlang-27-debian-bookworm-20250407-slim AS builder

RUN apt-get update -y && \
    apt-get install -y build-essential git curl nodejs npm && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Fetch dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy config files needed at compile time
COPY config/config.exs config/prod.exs config/

# Compile dependencies
RUN mix deps.compile

# Copy assets and compile them
COPY assets/ assets/
COPY priv/ priv/
COPY lib/ lib/

RUN mix assets.deploy

# Build release
RUN mix compile && mix release

# ---- Runtime stage ----
FROM docker.io/debian:bookworm-slim AS runtime

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV=prod
ENV PHX_SERVER=true

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/angivaonguoi ./

# Persist uploaded images outside the container via a volume
VOLUME ["/app/lib/angivaonguoi-0.1.0/priv/static/uploads"]

EXPOSE 4000

CMD ["bin/angivaonguoi", "start"]
