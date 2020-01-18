# perceptilabs-operator

## To Deploy the Operator Application to a Cluster

The following will deploy a demo version of the operator from our source on quay.io:
```
$ oc login <path to the cluster>
$ NAMESPACE=<your-namespace> PRODUCT_LEVEL=demo make deploy
```

## To remove PerceptiLabs from the cluster
```
PRODUCT_LEVEL=demo make clean-cluster
```
