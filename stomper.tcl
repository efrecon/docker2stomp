#! /usr/bin/env tclsh

set prg_args {
    -help     ""          "Print this help and exit"
    -verbose  0           "Verbosity level \[0-5\]"
    -docker   "unix:///var/run/docker.sock" "UNIX socket for connection to docker"
    -port     61613       "Port to send to"
    -host     localhost   "Hostname of remote server"
    -user     ""          "Username to authenticate with"
    -password ""          "Password to authenticate with"
    -tls      false       "Encrypt traffic using TLS?"
    -cafile   ""          "Path to CA file, if relevant"
    -certfile ""          "Path to cert file, if relevant"
    -keyfile  ""          "Path to key file, if relevant"
    -mapper   {}          "Mapping from container names/ids to topics"
    -output   stdout      "Which output of the docker containers to listen to"
    -retry    5000        "Milliseconds between container attachment retries"
}



set dirname [file dirname [file normalize [info script]]]
set appname [file rootname [file tail [info script]]]
lappend auto_path [file join $dirname lib]

package require stomp::client
package require docker


# Dump help based on the command-line option specification and exit.
proc ::help:dump { { hdr "" } } {
    global appname

    if { $hdr ne "" } {
	puts $hdr
	puts ""
    }
    puts "NAME:"
    puts "\t$appname - A STOMP forwarder, docker stdout --> STOMP topic"
    puts ""
    puts "USAGE"
    puts "\t${appname}.tcl \[options\]"
    puts ""
    puts "OPTIONS:"
    foreach { arg val dsc } $::prg_args {
	puts "\t${arg}\t$dsc (default: ${val})"
    }
    exit
}

proc ::getopt {_argv name {_var ""} {default ""}} {
    upvar $_argv argv $_var var
    set pos [lsearch -regexp $argv ^$name]
    if {$pos>=0} {
	set to $pos
	if {$_var ne ""} {
	    set var [lindex $argv [incr to]]
	}
	set argv [lreplace $argv $pos $to]
	return 1
    } else {
	# Did we provide a value to default?
	if {[llength [info level 0]] == 5} {set var $default}
	return 0
    }
}

array set FWD {}
foreach {arg val dsc} $prg_args {
    set FWD($arg) $val
}

if { [::getopt argv "-help"] } {
    ::help:dump
}

for {set eaten ""} {$eaten ne $argv} {} {
    set eaten $argv
    foreach opt [array names FWD -*] {
	::getopt argv $opt FWD($opt) $FWD($opt)
    }
}

# Arguments remaining?? dump help and exit
if { [llength $argv] > 0 } {
    ::help:dump "$argv are unknown arguments!"
}

proc ::forward { container topic type line } {
    global FWD

    if { $type eq "error" } {
	docker log WARN "Connection to $container lost,\
                         retrying in $FWD(-retry) ms"
	if { $FWD(-retry) >= 0 } {
	    after $FWD(-retry) [list ::init $container $url]
	}
	return
    }

    if { $line ne "" } {
	::stomp::client::send $FWD(client) $topic \
	    -body $line \
	    -type text/plain
    }
}

proc ::attach { container topic } {
    global DOCKER
    global FWD

    if { [catch {$DOCKER($container) inspect $container} descr] } {
	if { $FWD(-retry) >= 0 } {
	    docker log DEBUG "No container, retrying in $FWD(-retry) ms"
	    after $FWD(-retry) [list ::attach $container $topic]
	}
    } elseif { [dict exists $descr State Running] \
		   && [string is true [dict get $descr State Running]] } {
	docker log NOTICE "Attaching to container $container\
                           on $FWD(-output)"
	$DOCKER($container) attach $container \
	    [list ::forward $container $topic] \
	    stream 1 $FWD(-output) 1
    } elseif { $FWD(-retry) >= 0 } {
	docker log DEBUG "No container, retrying in $FWD(-retry) ms"
	after $FWD(-retry) [list ::attach $container $topic]
    }
}


proc ::init { container topic } {
    global DOCKER
    global FWD

    # Disconnect if we already have a connection
    if { [info exists DOCKER($container)] } {
	$DOCKER($container) disconnect
	unset DOCKER($container)
    }

    set DOCKER($container) [docker connect $FWD(-docker)]
    ::attach $container $topic
    return $DOCKER($container)
}

proc ::init:stomp { msg } {
    global FWD

    # Enumerate containers
    foreach { container topic } $FWD(-mapper) {
	::init $container $topic
    }
}

proc ::tlssocket { args } {
    global FWD

    if { [catch {eval [linsert $args 0 ::tls::socket \
			   -tls1 1 \
			   -cafile $FWD(-cafile) \
			   -certfile $FWD(-certfile) \
			   -keyfile $FWD(-keyfile)]} sock] == 0 } {
	fconfigure $sock -blocking 1 -encoding binary
	::tls::handshake $sock
	return $sock
    }
    return -code error $sock
}

::stomp::verbosity $FWD(-verbose)
::docker::verbosity $FWD(-verbose)
if { [string is true $FWD(-tls)] } {
    package require tls
    set FWD(client) [::stomp::client::connect \
			 -host $FWD(-host) \
			 -port $FWD(-port) \
			 -user $FWD(-user) \
			 -password $FWD(-password) \
			 -socketCmd ::tlssocket]
} else {
    set FWD(client) [::stomp::client::connect \
			 -host $FWD(-host) \
			 -port $FWD(-port) \
			 -user $FWD(-user) \
			 -password $FWD(-password)]
}
::stomp::client::handler $FWD(client) ::init:stomp CONNECTED

vwait forever
