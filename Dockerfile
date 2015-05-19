FROM efrecon/mini-tcl
MAINTAINER Emmanuel Frecon <emmanuel@sics.se>

# COPY code
COPY stomper.tcl /opt/docker2stomp/
RUN mkdir /opt/docker2stomp/lib

# Install git so we can install dependencies
RUN apk add --update-cache git

# Install tsdb into /opt and til in the lib subdirectory
WORKDIR /tmp
RUN git clone https://github.com/efrecon/tcl-stomp
RUN mv /tmp/tcl-stomp/lib/stomp /opt/docker2stomp/lib/
RUN git clone https://github.com/efrecon/docker-client
RUN mv /tmp/docker-client/docker /opt/docker2stomp/lib/
RUN rm -rf /var/cache/apk/*
WORKDIR /opt/docker2stomp

VOLUME ["/tmp/docker.sock"]

ENTRYPOINT ["tclsh8.6", "/opt/docker2stomp/stomper.tcl", "-docker", "unix:///tmp/docker.sock"]
CMD ["-verbose", "3"]
