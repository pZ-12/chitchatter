# Chitchatter — ephemeral P2P chat
# Multi-stage: build static assets, serve from minimal nginx + embedded tracker
# Runtime stores NOTHING — no volumes, no state, no logs

FROM node:20-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/jeremyckahn/chitchatter.git .
RUN npm pkg set homepage="/"
RUN npm ci
ENV VITE_HOMEPAGE=/
ENV VITE_ROUTER_TYPE=hash
ENV VITE_TRACKER_URL=wss://chitchatter.tail41d3d6.ts.net/tracker
RUN npx cross-env VITE_HOMEPAGE=/ vite build
# Replace ALL tracker references — both full wss:// URLs and bare hostnames
# that get prefixed with wss:// at runtime via .map()
RUN find dist/assets -name '*.js' -exec sed -i \
  -e 's|tracker\.btorrent\.xyz|chitchatter.tail41d3d6.ts.net/tracker|g' \
  -e 's|tracker\.openwebtorrent\.com|chitchatter.tail41d3d6.ts.net/tracker|g' \
  -e 's|tracker\.webtorrent\.dev|chitchatter.tail41d3d6.ts.net/tracker|g' \
  -e 's|tracker\.files\.fm:7073/announce|chitchatter.tail41d3d6.ts.net/tracker|g' \
  {} +

# Runtime — nginx serves SPA, supervisord runs both nginx + tracker
FROM node:20-alpine
RUN apk add --no-cache nginx supervisor
RUN npm install -g bittorrent-tracker
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/dist /usr/share/nginx/html
RUN printf 'server {\n\
  listen 80;\n\
  root /usr/share/nginx/html;\n\
  location /tracker {\n\
    proxy_pass http://127.0.0.1:8000/;\n\
    proxy_http_version 1.1;\n\
    proxy_set_header Upgrade $http_upgrade;\n\
    proxy_set_header Connection "upgrade";\n\
    proxy_set_header Host $host;\n\
    proxy_read_timeout 86400;\n\
  }\n\
  location / {\n\
    try_files $uri $uri/ /index.html;\n\
  }\n\
}\n' > /etc/nginx/http.d/default.conf
RUN printf '[supervisord]\nnodaemon=true\nlogfile=/dev/null\nlogfile_maxbytes=0\n\n\
[program:nginx]\ncommand=nginx -g "daemon off;"\nautorestart=true\nstdout_logfile=/dev/null\nstderr_logfile=/dev/null\n\n\
[program:tracker]\ncommand=bittorrent-tracker --ws --ws-port 8000 --http=false --udp=false --stats=false\nautorestart=true\nstdout_logfile=/dev/null\nstderr_logfile=/dev/null\n' > /etc/supervisord.conf
EXPOSE 80
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
