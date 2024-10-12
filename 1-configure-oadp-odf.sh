#!/bin/bash
# Script to configure OADP using ODF/MCG object storage
# This script should work on any cluster with ODF and MCG configured 

# How to configure this:
# https://docs.redhat.com/en/documentation/openshift_container_platform/4.16/html-single/backup_and_restore/index#installing-oadp-mcg

which jq || exit 1
which oc || exit 1

oc new-project demo-oadp || true

if ! oc get ObjectBucketClaim my-backup-bucket; then

oc -n demo-oadp apply -f - <<END
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  labels:
    bucket-provisioner: openshift-storage.ceph.rook.io-bucket
  name: my-backup-bucket
  namespace: demo-oadp
spec:
  bucketName: my-backup-bucket
  objectBucketName: obc-demo-oadp-my-backup-bucket
  storageClassName: ocs-storagecluster-ceph-rgw
END
	oc wait --for=jsonpath='{.status.phase}'=Bound ObjectBucketClaim/my-backup-bucket --timeout=120s
else
	echo Bucket my-backup-bucket already exists
fi

while ! oc get secret my-backup-bucket -n demo-oadp; do sleep 2; done

eval $(oc get secret my-backup-bucket -n demo-oadp -o go-template='{{range $k,$v := .data}}{{printf "%s='\''" $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"'\''\n"}}{{end}}')

echo "[default]
aws_access_key_id=$AWS_ACCESS_KEY_ID
aws_secret_access_key=$AWS_SECRET_ACCESS_KEY" > credentials-velero

oc delete secret cloud-credentials -n openshift-adp || true
oc create secret generic cloud-credentials -n openshift-adp --from-file cloud=credentials-velero

sleep 5

oc apply -f - <<END
apiVersion: oadp.openshift.io/v1alpha1
kind: DataProtectionApplication
metadata:
  name: my-dpa
  namespace: openshift-adp
spec:
  configuration:
    velero:
      defaultPlugins:
        - kubevirt
        - csi
        - aws
        - openshift
      resourceTimeout: 10m
      featureFlags:
        - EnableCSI
    nodeAgent:
      enable: true
      uploaderType: kopia
#      podConfig:
#        nodeSelector: <node_selector> 
  backupLocations:
    - velero:
        config:
          profile: default
          region: localstorage
          s3ForcePathStyle: 'true'
          s3Url: https://rook-ceph-rgw-ocs-storagecluster-cephobjectstore.openshift-storage.svc:443
          insecureSkipTLSVerify: "true"
        provider: aws
        default: true
        credential:
          key: cloud
          name: cloud-credentials
        objectStorage:
          bucket: my-backup-bucket
          prefix: my-bucket-prefix
END

sleep 5

oc get dpa my-dpa -n openshift-adp -o jsonpath='{.status}'| jq .
oc get all -n openshift-adp
#oc get backupStorageLocation -n openshift-adp -o yaml
oc wait --for=jsonpath='{.status.phase}'=Available backupStorageLocation/my-dpa-1 --timeout=120s -n openshift-adp
oc get backupStorageLocation -n openshift-adp -o jsonpath='{.items[0].status}'| jq .

