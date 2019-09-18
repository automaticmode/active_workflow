FROM local/active_workflow

USER 0

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

RUN LC_ALL=en_US.UTF-8 bundle install --with test development --path vendor/bundle -j 4

COPY docker/test/scripts/test_env /scripts/

# Override upstream script with the local one.
COPY docker/scripts/setup_env /scripts/
ENTRYPOINT ["/scripts/test_env"]
CMD ["rake spec"]

USER 1001
