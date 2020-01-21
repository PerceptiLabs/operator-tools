# perceptilabs-operator

## To Deploy the Operator Application to a Cluster

The following will deploy the operator from our source on quay.io:
```
$ oc login <path to the cluster>
$ NAMESPACE=<your-namespace> make deploy
```

## To remove PerceptiLabs from the cluster
```
$ NAMESPACE=<your-namespace> make clean-cluster
```
