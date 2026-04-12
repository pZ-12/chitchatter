# Chitchatter Container

Minimal Docker image for [Chitchatter](https://github.com/jeremyckahn/chitchatter) — a secure, peer-to-peer, ephemeral chat app.

The image builds Chitchatter from source and serves the static assets via nginx. **The runtime stores nothing** — no volumes, no database, no logs. All messaging is P2P via WebRTC; the server only serves the web app.

## Architecture

- Multi-stage build: Node 20 builds the Vite app, nginx:alpine serves it
- Multi-arch: linux/amd64 + linux/arm64
- Weekly rebuild via scheduled CI to pick up upstream changes

## Usage

```bash
docker run -p 8080:80 ghcr.io/pz-12/chitchatter:latest
```
