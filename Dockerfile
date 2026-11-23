# Tier B (💛 palladius private) — static site behind nginx Basic Auth on Cloud Run.
# Build context must contain dist-private/ (run `just build-b` first). Nothing in dist-private/
# is ever committed; the image is built by `gcloud run deploy --source .` from the local tree.
FROM nginx:alpine
RUN apk upgrade --no-cache && apk add --no-cache apache2-utils
COPY deploy/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY deploy/40-htpasswd.sh /docker-entrypoint.d/40-htpasswd.sh
RUN chmod +x /docker-entrypoint.d/40-htpasswd.sh
COPY dist-private/ /usr/share/nginx/html/
ENV PORT=8080
EXPOSE 8080
