# ── Stage 1: Base Image ──
FROM node:22-alpine AS base

RUN apk add --no-cache libc6-compat dumb-init
WORKDIR /app

# ── Stage 2: Deps (prod only) ──
FROM base AS deps

COPY package.json package-lock.json* ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev --ignore-scripts --prefer-offline && \
    npm cache clean --force

# ── Stage 3: Builder ──
FROM base AS builder

COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json* ./
COPY . .
RUN npm run build
RUN npm prune --production

# ── Stage 4: Runner ──
FROM base AS runner

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# ── Non-root user ──
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# ── Copy standalone build artifacts ──
COPY --from=builder --chown=nextjs:nodejs /app/next.config.mjs ./
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000 || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]