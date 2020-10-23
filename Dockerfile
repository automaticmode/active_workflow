FROM ruby:2.6.6-slim

COPY docker/scripts/prepare /scripts/
RUN /scripts/prepare

WORKDIR /app

COPY ./ /app/

ENV RAILS_ENV=production

# Get rid of annoying "fatal: Not a git repository (or any of the parent directories): .git" messages
RUN umask 002 && git init && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production SECRET_KEY_BASE=secret bundle install --redownload --no-local -j 4  && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production SECRET_KEY_BASE=secret bundle exec rake assets:clean assets:precompile && \
    chmod g=u /app/Gemfile.lock /app/config/ /app/tmp/


EXPOSE 3000

COPY docker/scripts/init /scripts/
CMD ["/scripts/init"]

USER 1001
