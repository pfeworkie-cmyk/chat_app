# --- STAGE 1: Build & Install Dependencies ---
FROM node:22-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force

# --- STAGE 2: Production Execution ---
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /usr/src/app

# Copy production dependencies from builder
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY package.json ./

# npm is needed only while building. Removing it from the runtime image also
# removes npm's bundled packages (including tar) from the Trivy scan surface.
RUN rm -rf /usr/local/lib/node_modules/npm \
    /usr/local/bin/npm \
    /usr/local/bin/npx

# Copy application files with unprivileged permissions
COPY --chown=node:node public ./public
COPY --chown=node:node server.js ./server.js

USER node
EXPOSE 3000

CMD ["node", "server.js"]
