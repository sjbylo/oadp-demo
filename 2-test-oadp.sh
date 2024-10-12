#!/bin/bash -e

echo_green()	{ [ "$TERM" ] && tput setaf 2; echo -e "$@"; [ "$TERM" ] && tput sgr0; }

oc get dpa my-dpa -n openshift-adp || ./1-configure-oadp-odf.sh

n=rhel9-$RANDOM

# Create vm
##oc get templates rhel9-server-tiny -n openshift -o yaml | sed "s/storage: 30Gi/storage: 10Gi/g" | \
oc process rhel9-server-tiny -n openshift -p NAME=$n | \
	sed 's#"running": false#"running": true#g' | \
	oc apply -f - -n demo-oadp
echo_green VM scheduled
sleep 2
oc get vm $n -n demo-oadp
#virtctl start $n -n demo-oadp
sleep 2

time oc wait --for=jsonpath='{.status.phase}'=Running vmi/$n --timeout=40s -n demo-oadp
sleep 1
echo_green VM runnning

# Waiting for agent to be connected
oc -n demo-oadp wait --for=jsonpath='{.status.conditions[?(@.type=="AgentConnected")].status}'=True vmi/$n --timeout=90s
echo_green VM agent up

oc get vmi $n -n demo-oadp

# backup
sed "s/rhel9-.*/$n/g" yaml/backup.yaml > backup.yaml
cat backup.yaml | oc apply -f - -n openshift-adp
echo_green Backup requested
sleep 2
time oc -n openshift-adp wait --for=jsonpath='{.status.phase}'=Completed backup.velero.io/backup-$n --timeout=40s
echo_green Backup complete
sleep 2

# Delete
oc delete vm $n -n demo-oadp
echo_green VM deleted
sleep 1

# restore
sed "s/rhel9-.*/$n/g" yaml/restore.yaml > restore.yaml
cat restore.yaml | oc apply -f - -n openshift-adp
echo_green Restore requested
sleep 1
time oc -n openshift-adp wait --for=jsonpath='{.status.phase}'=Completed restore.velero.io/restore-$n --timeout=40s
echo_green Restore complete
##virtctl start $n
oc get vmi $n -n demo-oadp
echo_green VM scheduled

oc wait --for=jsonpath='{.status.phase}'=Running vmi/$n --timeout=40s -n demo-oadp
echo_green VM running

oc get vmi -n demo-oadp

