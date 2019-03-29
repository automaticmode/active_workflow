FROM ubuntu:16.04

COPY docker/scripts/prepare /scripts/
RUN /scripts/prepare

WORKDIR /app

COPY ["Gemfile", "Gemfile.lock", "/app/"]
COPY lib/gemfile_helper.rb /app/lib/
COPY vendor/gems/ /app/vendor/gems/

# Get rid of annoying "fatal: Not a git repository (or any of the parent directories): .git" messages
RUN umask 002 && git init && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production SECRET_KEY_BASE=secret DATABASE_ADAPTER=postgresql bundle install --without "test development" --path vendor/bundle -j 4

COPY ./ /app/

RUN umask 002 && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production SECRET_KEY_BASE=secret DATABASE_ADAPTER=postgresql bundle exec rake assets:clean assets:precompile && \
    chmod g=u /app/Gemfile.lock /app/config/ /app/tmp/


EXPOSE 3000

COPY ["docker/scripts/setup_env", "docker/scripts/init", "/scripts/"]
CMD ["/scripts/init"]

USER 1001
