#!/bin/bash -ex

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

# Waiting for agent to be connected
oc -n demo-oadp wait --for=jsonpath='{.status.conditions[?(@.type=="AgentConnected")].status}'=True vmi/$n --timeout=90s

oc get vmi $n -n demo-oadp

# backup
sed "s/rhel9-1/$n/g" backup.yaml 
sed "s/rhel9-1/$n/g" backup.yaml | oc apply -f - -n openshift-adp
sleep 2
time oc -n openshift-adp wait --for=jsonpath='{.status.phase}'=Completed backup.velero.io/backup-$n --timeout=40s
sleep 2

# Delete
oc delete vm $n -n demo-oadp
sleep 1

# restore
sed "s/rhel9-1/$n/g" restore.yaml 
sed "s/rhel9-1/$n/g" restore.yaml | oc apply -f - -n openshift-adp
sleep 1
time oc -n openshift-adp wait --for=jsonpath='{.status.phase}'=Completed restore.velero.io/restore-$n --timeout=40s
sleep 2
##virtctl start $n
oc get vmi $n -n demo-oadp

