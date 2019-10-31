FROM ruby:2.6.3-slim

USER 0

COPY docker/scripts/prepare /scripts/
RUN /scripts/prepare

RUN apt-get update && \
    apt-get -y install \
      build-essential \
      chrpath \
      libgtk-3-0 \
      libdbus-glib-1-2 \
      xvfb \
      chromium chromium-driver \
      libssl-dev \
      libxft-dev \
      libfreetype6 \
      libfreetype6-dev \
      libfontconfig1 \
      libfontconfig1-dev curl && \
    apt-get -y clean

WORKDIR /app

COPY ./ /app/

RUN LC_ALL=en_US.UTF-8 umask 002 && bundle install --with test development --path vendor/bundle -j 4

COPY ["docker/scripts/setup_env", "docker/scripts/init", "docker/test/scripts/test_env", "/scripts/"]

EXPOSE 3000

ENTRYPOINT ["/scripts/test_env"]
CMD ["rake spec"]

USER 1001

