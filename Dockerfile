FROM docker.io/ruby:2.6.8-slim-buster

COPY docker/scripts/prepare_os /scripts/
RUN /scripts/prepare_os

VOLUME /var/lib/postgresql/11/main

WORKDIR /app

COPY --chown=active_workflow ./ /app/

RUN su active_workflow -c 'docker/scripts/prepare_app'

EXPOSE 3000

COPY docker/scripts/init /scripts/

ENTRYPOINT ["tini", "--", "/app/docker/scripts/entrypoint"]
