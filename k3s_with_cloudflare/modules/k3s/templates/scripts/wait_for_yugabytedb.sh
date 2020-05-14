#!/bin/bash
runtime="15 minute"
endtime=$(date -ud "$runtime" +%s)

while [[ $(date -u +%s) -le $endtime ]]; do
    if [ `kubectl -n $1 get statefulset | grep yb-tserver | awk '{print $2}'` = '3/3' ]; then
        break
    else
        echo "Waiting for YugaByte to become live... Sleeping ten seconds..."
        sleep 10
    fi
done
