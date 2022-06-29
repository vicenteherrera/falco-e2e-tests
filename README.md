# What it is

This project makes it easy for you to:
* Create a K3S cluster using Multipass virtual machine(s)
* Install Falco Helm chart (local files or published version number) with Kubernetes audit log enabled
* Optionally deploy Falco Sidekick with UI
* Optionally deploy Kubeless with `delete-pod` function (triggered by a running in a pod in `default` namespace)
  * Set up the whole chain of components `audit-logs` > `falco` > `falcosidekick` > `falcosidekick-ui` & `kubeless`
* Optinally run tests to check that Falco can detect a runtime event and a Kubernetes audit log event.

## Usage

```shell
# Create cluster, deploy chart, and execute tests with default values
./bootstrap.sh

# Check summary log
cat ./logs/summary.log

# In case of Falco pod errors, check log
cat ./logs/falco_pod.log

# Setup kubeconfig to access the cluster 
export KUBECONFIG=~/.kube/k3s.yaml

# Just execute tests on existing cluster any number of times
./tests.sh

# Destroy multipass cluster
multipass delete --all -p
```

Also check `makefile` for easy chained calls.

## Configuration

See variable definitions at the beginning of the `bootstrap.sh` script.

## Prerequisites

* multipass
* kubectl
* helm
* tee
* ts
* cut
* grep

## Authors

Vicente Herrera [[@vicenteherrera](https://github.com/)]  
Thomas Labarussias [[@Issif](https://github.com/Issif)]
