FROM efrecon/mini-tcl
MAINTAINER Emmanuel Frecon <emmanuel@sics.se>

# COPY code
COPY stomper.tcl /opt/docker2stomp/

# Install git so we can install dependencies
RUN mkdir /opt/docker2stomp/lib && \
    apk add --update-cache git && \
    git clone https://github.com/efrecon/tcl-stomp /tmp/tcl-stomp && \
    rm -rf /tmp/tcl-stomp/.git && \
    mv /tmp/tcl-stomp/lib/stomp /opt/docker2stomp/lib/ && \
    git clone https://github.com/efrecon/docker-client /tmp/docker-client && \
    rm -rf /tmp/docker-client/.git && \
    mv /tmp/docker-client/docker /opt/docker2stomp/lib/ && \
    apk del git && \
    rm -rf /var/cache/apk/*

VOLUME ["/tmp/docker.sock"]

ENTRYPOINT ["tclsh8.6", "/opt/docker2stomp/stomper.tcl", "-docker", "unix:///tmp/docker.sock", "-verbose", "3"]
