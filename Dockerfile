FROM efrecon/tcl
MAINTAINER Emmanuel Frecon <emmanuel@sics.se>


# Set the env variable DEBIAN_FRONTEND to noninteractive to get
# apt-get working without error output.
ENV DEBIAN_FRONTEND noninteractive

# Update underlying ubuntu image and all necessary packages, including
# docker itself so it is possible to run containers for sources or
# destinations.
RUN apt-get update
RUN apt-get install -y subversion

# COPY code
COPY stomper.tcl /opt/docker2stomp/
RUN mkdir /opt/docker2stomp/lib
RUN svn checkout https://github.com/efrecon/tcl-stomp/trunk/lib/stomp /opt/docker2stomp/lib/stomp
RUN svn checkout https://github.com/efrecon/docker-client/trunk/docker /opt/docker2stomp/lib/docker

VOLUME ["/tmp/docker.sock"]
ENTRYPOINT ["tclsh8.6", "/opt/docker2stomp/stomper.tcl", "-verbose", "3", "-docker", "unix:///tmp/docker.sock"]