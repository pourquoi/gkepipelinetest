FROM node:12-alpine as client-base

RUN mkdir -p /app/client
WORKDIR /app/client

RUN yarn global add @quasar/cli

COPY package.json yarn.lock ./

RUN yarn

FROM client-base as client-build

COPY . ./
# environment variables are not yet set, use args instead
ARG API_ENDPOINT
RUN API_ENDPOINT=${API_ENDPOINT}
RUN quasar build -m spa

FROM nginx:1.21-alpine as client-prod

COPY docker/nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=client-build /app/client/dist/spa /usr/share/nginx/html

CMD ["nginx", "-g", "daemon off;"]
