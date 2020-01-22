# perceptilabs-operator

## To deploy PerceptiLabs to a cluster

The following will deploy the operator from our source on quay.io:
```
$ oc login <path to the cluster>
$ NAMESPACE=<your-namespace> GPU_COUNT=1 make deploy
```
... or omit the GPU_COUNT to install in demo mode


## To remove PerceptiLabs from the cluster
```
$ NAMESPACE=<your-namespace> make clean-cluster
```

## To provision GPU machines in the cluster
1. Create a GPU-enabled machineset. Instructions are [here](https://blog.openshift.com/creating-a-gpu-enabled-node-with-openshift-4-2-in-amazon-ec2/)
1. Add a gpu count to the new machineset: `oc label machineset <machineset-name> gpus=<num-gpus>`
1. Scale up one GPU-enabled node:
   ```
   oc scale --namespace <machineset-namesapce> <machineset-name> --replicas=1
   ```
   ... wait for it to start and for a node to be assigned to the machine
1. Install the Node Feature Discovery (NFD) operator to the cluster. Instructions are [here](https://access.redhat.com/solutions/4734811)
1. Check that NFD is identifying NVIDIA GPUs. When NFD is working, the following will return rows:
   ```
   oc describe nodes | grep "pci-10de.present=true"
   ```
1. Install RedHat's Special Resource Operator to the cluster. It's not in the OperatorHub yet, so install from source:
   1. Get source:
      ```
      git clone https://github.com/openshift-psap/special-resource-operator
      cd special-resource-operator
      git checkout master
      ```
   1.  Edit assets/0000-state-driver-buildconfig.yaml to change spec.strategy.dockerStrategy.buildArgs to be:
   
       ```
       - name: "DRIVER_VERSION"
         value: "410.129-diagnostic"
       - name: "SHORT_DRIVER_VERSION"
         value: "410.129"
       ```
   1. Install it:
      ```
      make deploy
      ```
   1. Wait for it to mark the nodes with their gpu counts. The following should return rows:
      ```
      oc describe nodes | grep nvidia.com/gpu
      ```
      Note that it'll take a while since it needs to build drivers from source.

## To scale down machines labeled as gpu

```
oc scale machinesets --namespace <machineset-namespace> --selector 'gpus' --replicas=0
```

## To start a machine labeled as gpu

```
# Find a machineset to start:
oc get machinesets -A --show-labels --selector="gpus"

# Start it
oc scale machinesets -n <machineset-namespace> --replicas=1 <machineset-name>
``
