FROM node:22-alpine3.20 AS base

ENV DIR /app
WORKDIR $DIR
ARG NPM_TOKEN

FROM base AS dev

ENV NODE_ENV=development

COPY package*.json .

RUN echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > ".npmrc" && \
    npm ci && \
    rm -f .npmrc

COPY tsconfig*.json .
COPY .swcrc .
COPY nest-cli.json .
COPY src src

EXPOSE $PORT
CMD ["npm", "run", "dev"]

FROM base AS build

RUN apk update && apk add --no-cache dumb-init=1.2.5-r3

COPY package*.json .
RUN echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > ".npmrc" && \
    npm ci && \
    rm -f .npmrc

COPY tsconfig*.json .
COPY .swcrc .
COPY nest-cli.json .
COPY src src

RUN npm run build && \
    npm prune --production

FROM base AS production

ENV NODE_ENV=production
ENV USER=node

COPY --from=build /usr/bin/dumb-init /usr/bin/dumb-init
COPY --from=build $DIR/package*.json .
COPY --from=build $DIR/node_modules node_modules
COPY --from=build $DIR/dist dist

USER $USER
EXPOSE $PORT
CMD ["dumb-init", "node", "dist/main.js"]
