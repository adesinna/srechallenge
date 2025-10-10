FROM ubuntu:24.10

# uv binaries
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# working directory
WORKDIR /app

# system packages that are needed
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends build-essential git && rm -rf /var/lib/apt/lists/*

# install python version 3.12
RUN uv python install 3.12

# copy app code to the container
COPY . .

# install py dependencies from pyproject.toml file
RUN uv sync --frozen  # install exact version in the uv.lock file


# Expose the app port
EXPOSE 8000

# start the app
CMD ["uv", "run", "uvicorn", "main:api", "--host", "0.0.0.0", "--port", "8000", "--log-config", "logging.yaml"]