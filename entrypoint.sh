#!/bin/sh
set -e

CSROOT=/opt/CrowdStrike
FALCONCTL=$CSROOT/falconctl
FALCON_SENSOR=$CSROOT/falcon-sensor
CLOUDSIM_CID="YOURCID"

#
# Initialize ``opts`` as one-dimensional array
#
declare -A opts

#
# Pull options from the environment (passed to us through a Kubernetes
# config map). If $CLOUDSIM_CID is defined assume a local build.
#
# Reference output of ``falconctl --help`` for option descriptions.
#
opts['--cid']="${FALCONCTL_OPT_CID:-$CLOUDSIM_CID}"
opts['--aid']="$FALCONCTL_OPT_AID"
opts['--apd']="$FALCONCTL_OPT_APD"
opts['--aph']="$FALCONCTL_OPT_APH"
opts['--app']="$FALCONCTL_OPT_APP"
opts['--trace']="$FALCONCTL_OPT_TRACE"
opts['--feature']="$FALCONCTL_OPT_FEATURE"
opts['--message-log']="$FALCONCTL_OPT_MESSAGE_LOG"
opts['--billing']="$FALCONCTL_OPT_BILLING"
opts['--assert']="$FALCONCTL_OPT_ASSERT"
opts['--memfail-grace-period']="$FALCONCTL_OPT_MEMFAIL_GRACE_PERIOD"
opts['--memfail-every-n']="$FALCONCTL_OPT_MEMFAIL_EVERY_N"

#
# Iterate through the ``opts`` array and pull out defined options. Build a unified
# ``falconctl -s -f [OPTS]`` style command. 
#
cmd="$FALCONCTL -s -f"
for opt in "${!opts[@]}"
do
    [ -z ${opts[$opt]} ] || cmd+=" $opt=${opts[$opt]}"
done

#
# Set the sensor config by running $cmd, and then
# exec the sensor ($FALCON_SENSOR)
#
# Note this is why the ``set -e`` line earlier is so important. If $cmd fails
# we do not want the sensor daemon to initiate, as that would mean the sensor
# was not properly initiated.
echo $cmd
$cmd && exec $FALCON_SENSOR