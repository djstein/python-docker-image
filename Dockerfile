# syntax=docker/dockerfile:1
FROM ubuntu:latest as base

ENV \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    PATH="/opt/pyenv/shims:/opt/pyenv/bin:$PATH" \
    PYENV_ROOT="/opt/pyenv" \
    PYENV_SHELL="bash" \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=false \
    POETRY_VIRTUALENVS_CREATE=false \
    # PYENV_VERSION=2.3.35 \ using this causes the build to fail on pip install poetry!
    POETRY_VERSION=1.7.1 \
    PYTHON_VERSION=3.12.1

FROM base AS system-deps
RUN cp /etc/apt/sources.list /etc/apt/sources.list~ && \
    sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    build-essential gdb lcov pkg-config \
      libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
      libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev \
      lzma lzma-dev tk-dev uuid-dev zlib1g-dev \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM system-deps AS python-setup
RUN git clone -b v2.3.35 --single-branch --depth 1 https://github.com/pyenv/pyenv.git $PYENV_ROOT && \
    pyenv install ${PYTHON_VERSION} && \
    pyenv global ${PYTHON_VERSION} && \
    find $PYENV_ROOT/versions -type d '(' -name '__pycache__' -o -name 'test' -o -name 'tests' ')' -exec rm -rf '{}' + && \
    find $PYENV_ROOT/versions -type f '(' -name '*.pyo' -o -name '*.exe' ')' -exec rm -f '{}' + && \
    rm -rf /tmp/* && \
    pip install poetry==${POETRY_VERSION}

FROM python-setup AS poetry-install
WORKDIR /code/
COPY poetry.lock pyproject.toml /code/
RUN poetry install --no-dev --no-root --no-interaction --no-ansi

FROM base AS copy-codebase
WORKDIR /code/
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && update-ca-certificates --fresh
ENV SSL_CERT_DIR=/etc/ssl/certs
COPY --from=poetry-install $PYENV_ROOT $PYENV_ROOT
COPY hello_world.py .
RUN eval "$(pyenv init -)"