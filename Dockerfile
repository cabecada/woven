FROM ubuntu:20.04

USER root

RUN set -ex; \
        if ! command -v mkdocs > /dev/null; then \
                apt-get update && \
                apt-get install -y --no-install-recommends \
                        mkdocs curl && \
                rm -rf /var/lib/apt/lists/*; \
        fi

RUN set -eux; \
        groupadd -r mkdocs --gid=11000 && \
        useradd -r -g mkdocs --uid=11000 --home-dir=/var/mkdocs --shell=/bin/bash mkdocs && \
        mkdir -p /var/mkdocs && \
        chown -R mkdocs:mkdocs /var/mkdocs

COPY --chown=mkdocs:mkdocs docker-entrypoint.sh /var/mkdocs/docker-entrypoint.sh

RUN chmod u+x /var/mkdocs/docker-entrypoint.sh

USER mkdocs

WORKDIR /var/mkdocs

# use exec in script to ensure SIGINT terminates
STOPSIGNAL SIGINT

EXPOSE 8000

ENTRYPOINT ["/var/mkdocs/docker-entrypoint.sh"]
