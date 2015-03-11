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
    -mapper   {}          "Mapping from component names/ids to topics"
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

proc ::forward { component topic type line } {
    global FWD

    if { $line ne "" } {
	::stomp::client::send $FWD(client) $topic \
	    -body $line \
	    -type text/plain
    }
}


proc ::init { msg } {
    global FWD

    # Connect to docker
    set FWD(docker) [docker connect $FWD(-docker)]

    # Enumerate components
    foreach { component topic } $FWD(-mapper) {
	$FWD(docker) attach $component [list ::forward $component $topic] \
	    stream 1 stdout 1
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
::stomp::client::handler $FWD(client) ::init CONNECTED

vwait forever
