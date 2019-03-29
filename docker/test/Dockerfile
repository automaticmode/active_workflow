FROM local/active_workflow

ENV GECKODRIVER_URL "https://github.com/mozilla/geckodriver/releases/download/v0.24.0/geckodriver-v0.24.0-linux64.tar.gz"

USER 0

RUN apt-get update && \
    apt-get -y install \
      build-essential \
      chrpath \
      libgtk-3-0 \
      libdbus-glib-1-2 \
      xvfb \
      firefox \
      libssl-dev \
      libxft-dev \
      libfreetype6 \
      libfreetype6-dev \
      libfontconfig1 \
      libfontconfig1-dev curl && \
    apt-get -y clean && \
    curl -Ls ${GECKODRIVER_URL} \
      | tar zxvf - -C /usr/local/bin/ geckodriver

RUN LC_ALL=en_US.UTF-8 bundle install --with test development --path vendor/bundle -j 4

COPY docker/test/scripts/test_env /scripts/

# Override upstream script with the local one.
COPY docker/scripts/setup_env /scripts/
ENTRYPOINT ["/scripts/test_env"]
CMD ["rake spec"]

USER 1001
