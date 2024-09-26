oc delete dpa -n openshift-adp my-dpa && sleep 10
oc delete ObjectBucketClaim my-backup-bucket -n demo-oadp
rm -f credentials-velero
