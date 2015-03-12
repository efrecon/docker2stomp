# docker2stomp

This script will send the output of one or more docker components to
stomp queues.  Access to the docker components is via the API and the
local UNIX socket.  The option called `-mapper` should be of even
length where the odd elements (starting from the first!) are the names
(or identifiers) of the components and the even elements the full path
to the stomp topic to publish to.

The script listens to what is output on `stdout` at the Docker
component and publishes every message with the MIME type `text/plain`
to the topic.  In other words, starting with the following options on
the command line would attach to a component with identifier
`cfab5a50d83a` (a name works also well) and arrange for sending each
line that it outputs on `stdout` to the STOMP topic called
`/component/cfab5a50d83a/output` on a STOMP server running on the
localhost.  To get more help, for example, for how to refine the
details of the STOMP connection (username, TLS, etc.), use the
command-line option `-h`.

    stomper.tcl -mapper "cfab5a50d83a /component/cfab5a50d83a/output"

There is no polling for docker components occuring (or subscription to
their creation).  This means that if the components which names or
identifiers are specified under the `-mapper` option do not exist at
startup, their output will never be captured.

# Code Origin

To fill in the lib directory with a copy of the relevant libraries, do
the following from the main directory:

    svn checkout https://github.com/efrecon/tcl-stomp/trunk/lib/stomp lib/stomp
    svn checkout https://github.com/efrecon/docker-client/trunk/docker lib/docker
