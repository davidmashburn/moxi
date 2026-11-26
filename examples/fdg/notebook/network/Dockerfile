# Runtime-only consumers of the P04 assets built with its validated toolchain.
FROM node:24.11.1-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
COPY requirements*.txt /opt/fixture/
RUN pip install --no-cache-dir -r /opt/fixture/requirements-interactive.txt jupyter_kernel_gateway==3.0.1
WORKDIR /workspace
