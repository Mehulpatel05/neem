FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./
RUN npm ci --only=production

COPY src/ ./src/
RUN npx tsc --build

EXPOSE 8787

CMD ["node", "dist/src/index.js"]
