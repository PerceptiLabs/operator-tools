# staging tools

This is for deploying PerceptiLabs Modeling to a staging namespace in an OpenShift cluster.

## Prerequisites
* The `oc` CLI for your OS. Currently [here](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.2/)
* Login creds for the cluster

## Installation

1. Clone this repo
1. cd into `staging`

## Get available staging namespaces

```
./list-staging-namespaces
```

## Claiming a staging namespace

```
./claim <namespace> <your name>
```

## Unclaim

When you're done using the staging environment, remove your claim on it with:

```
./unclaim <namespace>
```

## Deployment

1. If you haven't already, log in to the cluster with `oc login <cluster>`.
   For example: `oc login https://api.os01.perceptilabshosting.com:6443` 
1. If you're creating a new namespace, then set PERCEPTILABS_AZURECR_PWD to the value from the Azure portal.
   Otherwise, if you're reusing a preexisting staging namespace, then that should already be set up.
1. Run `./setup <namespace> <modeling docker tag> <your name>` . It will tell you the frontend URL at the end.
1. Copy test data to the staging environment: `./upload_file <namespace> <the file>`

