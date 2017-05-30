FROM openjdk:8-jdk
LABEL maintainer="Butter.ai <dev@butter.ai>"

ENV SOLR_USER=solr \
    SOLR_UID=8983 \
    GOSU_VERSION=1.10 \
    PATH=/opt/solr/bin:/opt/docker-solr/scripts:$PATH

RUN groupadd -r -g $SOLR_UID $SOLR_USER \
 && useradd -r -u $SOLR_UID -G $SOLR_USER -g $SOLR_USER $SOLR_USER

# grab gosu for easy step-down from root
RUN set -x \
 && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
 && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
 && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
 && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
	ant \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone git://github.com/butter/lucene-solr.git \
 && cd lucene-solr \
 && git checkout tags/butter-solr/0.0.4 \
 && mv lucene-solr/lucene /opt/lucene \
 && mv lucene-solr/solr /opt/solr

COPY scripts /opt/docker-solr/scripts

RUN mkhomedir_helper $SOLR_USER \
 && mkdir /docker-entrypoint-initdb.d \
 && chown -R $SOLR_USER:$SOLR_USER /opt/solr /opt/lucene /opt/docker-solr

USER $SOLR_USER

RUN cd /opt/lucene \
 && ant ivy-bootstrap \
 && ant compile \
 && cd ../solr \
 && ant ivy-bootstrap \
 && ant compile \
 && ant server

RUN mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores \
 && sed -i -e 's/#SOLR_PORT=8983/SOLR_PORT=8983/' /opt/solr/bin/solr.in.sh \
 && sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh

EXPOSE 8983
WORKDIR /opt/solr
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
