# Artichoke Chat

A small Express and Socket.IO chat application.

## Run locally

```sh
npm ci
npm start
```

The server listens on port `3000` by default. Set `PORT` to change it. The chat accepts same-origin browser connections by default. If the frontend is hosted on a different origin, set `ALLOWED_ORIGINS` to a comma-separated list of exact origins, for example `https://chat.example.com,https://www.example.com`.

`MAX_MESSAGE_LENGTH` sets the maximum message length (default `2000`, capped at `10000`), and `MAX_CONNECTIONS` limits concurrent connections per server process (default `1000`, capped at `10000`). Invalid or non-positive values use the safe defaults.

## Checks

```sh
npm test
npm run lint
npm audit
```

The browser renders user-provided chat content as text. Keep that behavior; do not replace it with `innerHTML`. The Socket.IO browser client is served by the same-origin server. The remaining pinned CDN assets use Subresource Integrity and are restricted by the Content Security Policy.
