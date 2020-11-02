# perceptilabs-operator

## To deploy PerceptiLabs to a cluster

The following will deploy the operator from our source on quay.io:
```
$ oc login <path to the cluster>
$ NAMESPACE=<your-namespace> RELEASE_VERSION=1.0.20 GPU_COUNT=1 make deploy
```
... or omit the GPU_COUNT to install in demo mode


## To remove PerceptiLabs from the cluster
```
$ NAMESPACE=<your-namespace> make clean-cluster
```

## To provision GPU machines in the cluster
1. Find a region where your desired machine is available. For example:  
   ```
   az vm list-skus --resource-type virtualMachines --output table
   ```  
   will return a table of virtual machine types available in various Azure regions.
1. Create a GPU-enabled machineset. Instructions are [here](https://blog.openshift.com/creating-a-gpu-enabled-node-with-openshift-4-2-in-amazon-ec2/)
1. Add a gpu count label to the new machineset: `oc label machineset <machineset-name> gpus=<num-gpus>`
1. Add an availability zone label to the new machineset: `oc label machineset <machineset-name> az=<availability zone>`
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

For example, to start a 1-gpu machineset in us-east-2a:
```
oc scale machinesets.machine.openshift.io -n openshift-machine-api --selector="gpus=1,az=us-east-2a" --replicas=1
```

Wait for the SRO to recognize the GPUs:
```
oc describe nodes | grep nvidia.com/gpu
```
Note that it'll take a while since it needs to build drivers from source.

If it takes more than 15 minutes, you can try restarting the SRO:
```
oc scale deployment -n openshift-sro special-resource-operator --replicas=0
oc scale deployment -n openshift-sro special-resource-operator --replicas=1
```
... and then watch for it to recognize the GPUs
