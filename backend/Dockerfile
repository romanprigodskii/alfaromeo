# Production image for the Альфа-Ромео backend (NestJS). Single-stage — the app is small.
FROM node:20-alpine
WORKDIR /app

# Install deps from the lockfile first for better layer caching.
COPY package.json package-lock.json ./
RUN npm ci

# App source + compiled build.
COPY . .
RUN npm run build

ENV NODE_ENV=production
EXPOSE 4000
CMD ["node", "dist/main"]
