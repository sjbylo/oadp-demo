#!/bin/bash -e

echo_green()	{ [ "$TERM" ] && tput setaf 2; echo -e "$@"; [ "$TERM" ] && tput sgr0; }

n=rhel9-$RANDOM

# Create vm
##oc get templates rhel9-server-tiny -n openshift -o yaml | sed "s/storage: 30Gi/storage: 10Gi/g" | \
oc process rhel9-server-tiny -n openshift -p NAME=$n | oc apply -f - -n demo-oadp
sleep 2
oc get vm $n -n demo-oadp
virtctl start $n -n demo-oadp
sleep 2

time oc wait --for=jsonpath='{.status.phase}'=Running vmi/$n --timeout=40s -n demo-oadp
sleep 1
echo_green VM runnning

# Waiting for agent to be connected
oc -n demo-oadp wait --for=jsonpath='{.status.conditions[?(@.type=="AgentConnected")].status}'=True vmi/$n --timeout=90s
echo_green VM agent up

oc get vmi $n -n demo-oadp

# backup
sed -i "s/rhel9-.*/$n/g" backup.yaml 
cat backup.yaml | oc apply -f - -n openshift-adp
sleep 2
time oc -n openshift-adp wait --for=jsonpath='{.status.phase}'=Completed backup.velero.io/backup-$n --timeout=40s
echo_green Backup complete
sleep 2

# Delete
oc delete vm $n -n demo-oadp
echo_green VM deleted
sleep 1

# restore
sed -i "s/rhel9-.*/$n/g" restore.yaml 
cat restore.yaml | oc apply -f - -n openshift-adp
sleep 1
time oc -n openshift-adp wait --for=jsonpath='{.status.phase}'=Completed restore.velero.io/restore-$n --timeout=40s
echo_green Restore complete
sleep 2
##virtctl start $n
oc get vmi $n -n demo-oadp
echo_green VM scheduled

