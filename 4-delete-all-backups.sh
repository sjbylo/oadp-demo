#!/bin/bash 

cat > /tmp/.DeleteBackupRequest.template.yaml <<END
apiVersion: velero.io/v1
kind: DeleteBackupRequest
metadata:
  name: deletebackuprequest
  namespace: openshift-adp
spec:
 backupName: NAME
END

oc get backup -n openshift-adp -oname | cut -d/ -f2 | while read name
do
	echo $name
	cat /tmp/.DeleteBackupRequest.template.yaml | sed -e "s/NAME/$name/g" -e "s/deletebackuprequest/deletebackuprequest-$name/g" | oc apply -f - 
done

