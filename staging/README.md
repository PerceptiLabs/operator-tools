# staging tools

This is for deploying PerceptiLabs Modeling to a staging namespace in an OpenShift cluster.

## Prerequisites
* oc
* Login creds for the cluster

## Get available staging namespaces

```
./list-staging-namespaces
```

## Deployment

1. If you haven't already, log in to the cluster with `oc login <cluster>`. For example: `oc login https://api.os01.perceptilabshosting.com:6443` 
1. If you're creating a new namespace, then set PERCEPTILABS_AZURECR_PWD to the value from the Azure portal.
   Otherwise, if you're reusing a preexisting staging namespace, then that should already be set up.
1. Run `./setup <namespace> <modeling docker tag>` . It will tell you the frontend URL at the end.
1. Copy test data to the staging environment: `./upload_file <namespace> <the file>`

