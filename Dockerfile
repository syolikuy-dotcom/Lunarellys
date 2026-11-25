FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY package.json package-lock.json index.js ./
COPY src ./src
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 3000
CMD ["node", "index.js"]
