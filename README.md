# docker2stomp

This small script will send the output of docker components to stomp
queues.  Access to the docker components is via the API and the local
UNIX socket.  The option called `-mapper` should be of even length
where the odd elements (starting from the first!) are the names (or
identifiers) of the components and the even elements the full path to
the stomp topic to publish to.

The script listens to what is output on stdout and publishes every
message with the MIME type `text/plain` to the topic.

# Code Origin

To fill in the lib directory with a copy of the relevant libraries, do
the following from the main directory:

    svn checkout https://github.com/efrecon/tcl-stomp/trunk/lib/stomp lib/stomp
    svn checkout https://github.com/efrecon/docker-client/trunk/docker lib/docker
