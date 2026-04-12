# Chitchatter — ephemeral P2P chat
# Multi-stage: build static assets, serve from minimal nginx
# Runtime stores NOTHING — no volumes, no state, no logs

FROM node:20-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/jeremyckahn/chitchatter.git .
# Override homepage to / for self-hosting; use hash router so server never sees room names
RUN npm pkg set homepage="/"
RUN npm ci
ENV VITE_HOMEPAGE=/
ENV VITE_ROUTER_TYPE=hash
RUN npx cross-env VITE_HOMEPAGE=/ vite build

# Minimal runtime — static files only, read-only filesystem safe
FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/dist /usr/share/nginx/html
# SPA routing — all paths serve index.html
RUN printf 'server {\n  listen 80;\n  root /usr/share/nginx/html;\n  location / {\n    try_files $uri $uri/ /index.html;\n  }\n}\n' > /etc/nginx/conf.d/default.conf
EXPOSE 80
