# OADP Demo using ODF Object Storage

## Prerequisites

- Install OpenShift and configure ODF. Ensure the 'openshift-storage.ceph.rook.io/bucket' storage class exists.
- Install the OADP Operator.

Then, install and configure OADP (ensure 'jq' and 'oc' are installed):

```
./1-create-oadp-odf.sh
```
- This will create a project called demo-oadp
- You must see "Successful" in the output.  If not, troubleshoot!


Test using this simple script. Ensure 'virtctl' is installed and working.
```
./2-test-oadp.sh
```

Clean up *all* backups.
```
./4-delete-all-backups.sh
```

Clean up OADP config.
```
./3-delete-oadp-odf.sh
```

Clean up all VMs in ns demo-oadp.
```
./5-delete-all-vms.sh
```
