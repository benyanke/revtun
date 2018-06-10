# revtun

revtun is a simple replacement for AutoSSH written in pure bash. It's best for situations where you can install a shell script but
perhaps a package manager is not available, and you just need a reverse SSH tunnel.

Edit the script to configure it, and run in cron to ensure tunnel stays alive. The script stores the PID of the tunnel in a pid file,
and when checking to see if the tunnel is up, it first checks the pid file, and then attempts to ping hosts through the tunnel.

Travis builds also run, linting the script with `shellcheck`. 

__NOTE: this is not yet complete__
