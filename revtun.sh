#!/bin/bash

#################
#
# revtun - A reverse SSH tunnel with keepalive in pure bash
#
# An alternative to autossh. By Ben Yanke <ben@benyanke.com>
# Run this regularly in cron to keep the tunnel alive.
#
# https://github.com/benyanke/revtun
#
#################


#################
# Configuration
#################

## Connection settings

# Connection string for SSH tunnel host
export sshConnectionString="user@host"

# These hosts must be only accessable from the other end of the tunnel.
# If these IPs respond to pings, we assume the tunnel is online.
# If they do not respond, we will assume the tunnel is down, kill the SSH PID,
# and restart.

# Seperate hosts by spaces, add as many as you want. If even one of the hosts responds, the tunnel is
# assumed up, so ensure every one is only accessable by tunnel.
# Specifying multiple hosts allows the health check to work properly even if one unexpectedly goes down.
export healthCheckHosts="10.10.10.1 10.10.10.10"

## These two typically don't need to be edited
# Will attempt this many pings before failing
export healthCheckCount="3"
# Timeout (sec) before a ping is marked as failed.
export healthCheckTimeout="1"


export localPort="22" # Local port to forward
export remoteBindPort="8200" # Port to bind to on remote host
export keyFile="" # Full path to SSH key
export pidFile="/tmp/sshtun/pidfile" # PID file


## Script settings
export killWaitTime="2"

#################
# Functions
#################

# Check if tunnel is up. Return '0' if up, return '254' if down.
function checkTunnelStatus() {

  good="0"
  err="254"

  echo "Checking if tunnel is up..."

  # First - check PID file. If PID file is empty, we'll consider SSH dead.
  if [ -s "$pidFile" ] ; then
    # Get the PID from the file
    pid="$(cat $pidFile)"

    # If not dead after a nice kill, keep trying to hard-kill until it dies
    if [[ "$(ps -p "$pid" &> /dev/null ; echo $?)" = "0" ]] ; then
      # PID exists
      echo "Tunnel PID exists - continuing"
      # ping logic is broken - temporarily returning here, using only the PID as the measure of a tunnel up
      return $good
    else
      # PID does not exist
      return $err;
    fi

  else
    echo "No PID file - tunnel assumed to be down"
    return $err;
  fi


  # If we reach here, the PID exists.
  # Now check the actual tunnel status by pinging the check address.
  # This address is one configured above to be on the other side of the tunnel. If it can be pinged,
  # the tunnel must be up.

  # Loop through the health check hosts
  for host in $healthCheckHosts ; do

    echo "Checking health check $host"
    ping -c $healthCheckCount -W $healthCheckTimeout -i 0.2 "$host" &> /dev/null
    pingResult="$?";

    # Check return status of ping to see if host is there
    if [[ "$pingResult" = "0" ]] ; then
      echo "Health check host $host returned GOOD. Tunnel is up."
      return $good;
    else
      echo "Health check host $host returned BAD. Checking other hosts, in case this host is having issues.";
    fi

  done;

  echo "All health check hosts are down - Tunnel is down.";
  return $err;

}

# Kill the old SSH connection to ensure the port forward is clear
function killOldSshConnection() {

  # If there is a PID in the PIDfile, kill the PID specified
  if [ -s "$pidFile" ] ; then
    # Get the PID from the file
    pid="$(cat $pidFile)"

    # Try a nice kill first
    kill "$pid" &> /dev/null
    echo "Killing SSH at PID $pid"

    # If not dead after a nice kill, keep trying to hard-kill until it dies
    while [[ "$(ps -p "$pid" &> /dev/null ; echo $?)" = "0" ]] ; do
      sleep "$killWaitTime";
      echo "SSH did not die. Running kill -9 on PID $pid and waiting $killWaitTime".
      kill -9 "$pid" &> /dev/null
    done

    echo "SSH PID $pid was killed successfully."

  else
    echo "No SSH running in PID file - continuing"
  fi
}

# Make the SSH connection and store the PID
function makeSshConnection() {

  # Make directory for PID file
  pidFileDir="$(dirname $pidFile)"
  mkdir -p "$pidFileDir"

  ssh -f -N -T \
    -i "$keyFile" \
    -R"$remoteBindPort:localhost:$localPort" \
    $sshConnectionString; sshpid="$!"

  # Store PID in PIDfile
  echo "$sshpid" > "$pidFile"
}


#################
# Main
#################

# Check tunnel status - First checks the stored PID of the known tunnel, then tries to ping down the tunnel
checkTunnelStatus
tunStat="$?"

# If tunnel is down, kill previous tunnel (which may have stalled), then make new one.
if [[ "$tunStat" -ne "0" ]] ; then
  killOldSshConnection
  makeSshConnection
fi

# If we've reached here without an error, we're good to go!
exit 0;

