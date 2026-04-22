# ── Stage 1: Base Image ──
FROM node:22-alpine AS base

RUN apk add --no-cache libc6-compat dumb-init
WORKDIR /app

# ── Stage 2: Deps (prod only) ──
FROM base AS deps

COPY package.json package-lock.json* ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev --prefer-offline && \
    npm cache clean --force

# ── Stage 3: Builder ──
FROM base AS builder

COPY package.json package-lock.json* ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline && \
    npm cache clean --force

COPY . .
#  generate client first
RUN npx prisma generate  

RUN npm run build
RUN npm prune --production

# ── Stage 4: Runner ──
FROM base AS runner

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

WORKDIR /app

# ── Run as non-root user ──
USER node

# ── Copy build output + prod deps ──
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/package.json ./package.json

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
