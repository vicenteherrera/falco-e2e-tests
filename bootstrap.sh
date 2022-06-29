#!/bin/bash

set -e

START_TIME=$(date +'%Y-%m-%d %H:%M')
echo "Executing script for end-to-end testing of Falco Helm chart" | tee ./logs/summary.log
echo "Starting execution at: $START_TIME" | tee -a ./logs/summary.log

# Configuration

# MULTINODE: 0 -> use single node, 1 -> use 1 master 2 worker
MULTINODE=0

# INSTALL_KUBELESS: 0 -> no, 1 -> yes
INSTALL_KUBELESS=0

# INSTALL_SIDEKICK: 0 -> no, 1 -> yes
INSTALL_SIDEKICK=0

# RUN_TESTS: 0 -> no, 1 -> yes
RUN_TESTS=1

# FALCO_CHART_LOCATION: "" -> use online version , "./local_dir"  -> use local dir
FALCO_CHART_LOCATION=""
# FALCO_CHART_LOCATION=./charts/falco


# Latest known working configuration

K3S_WORKING="v1.21.11+k3s1"
FALCO_CHART_WORKING="1.17.3"
KUBELESS_WORKING="v1.0.8"
SIDEKICK_UI_WORKING="v2.0.2"

# Latest published versions

echo "Reading latest versions..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
K3S_LATEST=$(curl -Ls https://api.github.com/repos/k3s-io/k3s/releases/latest | grep tag_name | cut -d '"' -f 4)
FALCO_CHART_LATEST=$(curl -Ls https://raw.githubusercontent.com/falcosecurity/charts/master/falco/Chart.yaml | yq '.version')
KUBELESS_LATEST=$(curl -Ls https://api.github.com/repos/kubeless/kubeless/releases/latest | grep tag_name | cut -d '"' -f 4)
SIDEKICK_UI_LATEST=$(curl -Ls https://api.github.com/repos/falcosecurity/falcosidekick-ui/releases/latest | grep tag_name | cut -d '"' -f 4)

# Set up here your desired versions to test

K3S_VERSION="$K3S_WORKING"
FALCO_CHART_VERSION="$FALCO_CHART_WORKING"
KUBELESS_VERSION="$KUBELESS_WORKING"
SIDEKICK_UI_VERSION="$SIDEKICK_UI_WORKING"

# Display initial information

K3S_LABEL=FALCO_CHART_LABEL=KUBELESS_LABEL=""
[ "$K3S_VERSION" == "$K3S_WORKING" ] && K3S_LABEL="working"
[ "$K3S_VERSION" == "$K3S_LATEST" ] && K3S_LABEL="latest"
[ "$FALCO_CHART_VERSION" == "$FALCO_CHART_WORKING" ] && FALCO_CHART_LABEL="working"
[ "$FALCO_CHART_VERSION" == "$FALCO_CHART_LATEST" ] && FALCO_CHART_LABEL="latest"
[ "$KUBELESS_VERSION" == "$KUBELESS_WORKING" ] && KUBELESS_LABEL="working"
[ "$KUBELESS_VERSION" == "$KUBELESS_LATEST" ] && KUBELESS_LABEL="latest"
[ "$SIDEKICK_UI_VERSION" == "$SIDEKICK_UI_WORKING" ] && SIDEKICK_UI_LABEL="working"
[ "$SIDEKICK_UI_VERSION" == "$SIDEKICK_UI_LATEST" ] && SIDEKICK_UI_LABEL="latest"

[ "$FALCO_CHART_LOCATION" != "" ] && FALCO_CHART_VERSION="$FALCO_CHART_LOCATION" && FALCO_CHART_LABEL="local chart"

echo "K3S using version : $K3S_VERSION ($K3S_LABEL)" | tee -a ./logs/summary.log
echo "  latest version  : $K3S_LATEST" | tee -a ./logs/summary.log
echo "  known working   : $K3S_WORKING" | tee -a ./logs/summary.log

echo "Falco chart using version : $FALCO_CHART_VERSION ($FALCO_CHART_LABEL)" | tee -a ./logs/summary.log
echo "  latest version          : $FALCO_CHART_LATEST" | tee -a ./logs/summary.log
echo "  known working           : $FALCO_CHART_WORKING" | tee -a ./logs/summary.log

if [ $INSTALL_SIDEKICK -ne 0 ]; then
  echo "Falco Sidekick UI using version : $SIDEKICK_UI_VERSION ($SIDEKICK_UI_LABEL)" | tee -a ./logs/summary.log
  echo "  latest version                : $SIDEKICK_UI_LATEST" | tee -a ./logs/summary.log
  echo "  known working                 : $SIDEKICK_UI_WORKING" | tee -a ./logs/summary.log
fi

if [ $INSTALL_KUBELESS -ne 0 ]; then
  echo "Kubeless using version : $KUBELESS_VERSION ($KUBELESS_LABEL)" | tee -a ./logs/summary.log
  echo "  latest version       : $KUBELESS_LATEST" | tee -a ./logs/summary.log
  echo "  known working        : $KUBELESS_WORKING" | tee -a ./logs/summary.log
fi

if [ $MULTINODE -ne 0 ]; then 
  # Multi node cluster
  echo "Multi node cluster: 1 master, 2 worker nodes" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
  multipass launch --name k3s-master --cpus 1 --mem 2048M --disk 10G
  multipass launch --name k3s-node1 --cpus 1 --mem 2048M --disk 15G
  multipass launch --name k3s-node2 --cpus 1 --mem 2048M --disk 15G
  multipass exec k3s-master -- /bin/bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_KUBECONFIG_MODE=644 sh -"
  export K3S_TOKEN="$(multipass exec k3s-master -- /bin/bash -c "sudo cat /var/lib/rancher/k3s/server/node-token")"
  export K3S_IP_SERVER="https://$(multipass info k3s-master | grep "IPv4" | awk -F' ' '{print $2}'):6443"
  multipass exec k3s-node1 -- /bin/bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=${K3S_TOKEN} K3S_URL=${K3S_IP_SERVER} sh -"
  multipass exec k3s-node2 -- /bin/bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=${K3S_TOKEN} K3S_URL=${K3S_IP_SERVER} sh -"
else
  # Single node cluster
  echo "Single node cluster" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
  multipass launch --name k3s-master --cpus 1 --mem 2048M --disk 20G
  multipass exec k3s-master -- /bin/bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_KUBECONFIG_MODE=644 sh -"
fi

# Extract kubeconfig
export K3S_IP_SERVER="https://$(multipass info k3s-master | grep "IPv4" | awk -F' ' '{print $2}'):6443"
multipass exec k3s-master -- /bin/bash -c "cat /etc/rancher/k3s/k3s.yaml" | sed "s%https://127.0.0.1:6443%${K3S_IP_SERVER}%g" | sed "s/default/k3s/g" > ~/.kube/k3s.yaml
export KUBECONFIG=~/.kube/k3s.yaml

echo "Waiting 2 seconds"
sleep 2

# Node information

echo "K3S cluster deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

multipass exec k3s-master -- lsb_release -a | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
multipass exec k3s-master -- uname -r | ts '[%Y-%m-%d %H:%M:%S] Kernel: ' | tee -a ./logs/summary.log

# Install falco
if [ "$FALCO_CHART_LOCATION" == "" ]; then
  helm repo add falcosecurity https://falcosecurity.github.io/charts
  FALCO_CHART_LOCATION="falcosecurity/falco"
  CHART_VERSION_PARAM="--version $FALCO_CHART_VERSION"
else 
  CHART_VERSION_PARAM=""
fi

SIDEKICK_PARAM=""
if [ $INSTALL_SIDEKICK -ne 0 ]; then
  SIDEKICK_PARAM="--set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set falcosidekick.image.tag=latest \
  --set falcosidekick.webui.image.tag=${SIDEKICK_VERSION} \
  --set falcosidekick.config.kubeless.namespace=kubeless \
  --set falcosidekick.config.kubeless.function=delete-pod"
  echo "Including sidekick with Falco" | tee -a ./logs/summary.log
fi

INSTALL_COMMAND="helm install falco "$FALCO_CHART_LOCATION" -n falco --create-namespace \
  $CHART_VERSION_PARAM \
  -f custom-rules.yaml \
  --set auditLog.enabled=true $SIDEKICK_PARAM"

echo "Installing Falco helm chart using:" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
echo "$INSTALL_COMMAND" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

eval $INSTALL_COMMAND
  
echo "Falco helm chart deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

# Set up audit log endpoint (falco)
# Prepare for audit log
multipass exec k3s-master -- /bin/bash -c "sudo mkdir -p /var/lib/rancher/audit"
multipass exec k3s-master -- /bin/bash -c "wget https://raw.githubusercontent.com/falcosecurity/evolution/master/examples/k8s_audit_config/audit-policy.yaml"
multipass exec k3s-master -- /bin/bash -c "sudo cp audit-policy.yaml /var/lib/rancher/audit/"

export FALCO_SVC_ENDPOINT=$(kubectl get svc -n falco --field-selector metadata.name=falco -o=json | jq -r ".items[] | .spec.clusterIP")
cat <<EOF > webhook-config.yaml
apiVersion: v1
kind: Config
clusters:
- name: falco
  cluster:
    server: http://${FALCO_SVC_ENDPOINT}:8765/k8s-audit
contexts:
- context:
    cluster: falco
    user: ""
  name: default-context
current-context: default-context
preferences: {}
users: []
EOF
multipass transfer webhook-config.yaml k3s-master:/tmp/
multipass exec k3s-master -- /bin/bash -c "sudo cp /tmp/webhook-config.yaml /var/lib/rancher/audit/"
multipass exec k3s-master -- /bin/bash -c "sudo sed -i '/^$/d' /etc/systemd/system/k3s.service"
multipass exec k3s-master -- /bin/bash -c "sudo chmod o+w /etc/systemd/system/k3s.service"
multipass exec k3s-master -- /bin/bash -c "sudo echo '    --kube-apiserver-arg=audit-log-path=/var/lib/rancher/audit/audit.log \' >> /etc/systemd/system/k3s.service"
multipass exec k3s-master -- /bin/bash -c "sudo echo '    --kube-apiserver-arg=audit-policy-file=/var/lib/rancher/audit/audit-policy.yaml \' >> /etc/systemd/system/k3s.service"
multipass exec k3s-master -- /bin/bash -c "sudo echo '    --kube-apiserver-arg=audit-webhook-config-file=/var/lib/rancher/audit/webhook-config.yaml \' >> /etc/systemd/system/k3s.service"
multipass exec k3s-master -- /bin/bash -c "sudo chmod o-w /etc/systemd/system/k3s.service"
multipass exec k3s-master -- /bin/bash -c "sudo systemctl daemon-reload"
multipass exec k3s-master -- /bin/bash -c "sudo systemctl restart k3s"

echo "Waiting 5 seconds"
sleep 5
echo "Kubernetes audit log instrumentation deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

if [ $INSTALL_KUBELESS -ne 0 ]; then 

  # Install kubeless + Function
  kubectl create ns kubeless
  kubectl create -n kubeless -f \
    https://github.com/kubeless/kubeless/releases/download/$KUBELESS_VERSION/kubeless-$KUBELESS_VERSION.yaml

  cat <<EOF | kubectl apply -n kubeless -f -
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: falco-pod-delete
  ---
  kind: ClusterRole
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: falco-pod-delete-cluster-role
  rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["get", "list", "delete"]
  ---
  kind: ClusterRoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: falco-pod-delete-cluster-role-binding
  roleRef:
    kind: ClusterRole
    name: falco-pod-delete-cluster-role
    apiGroup: rbac.authorization.k8s.io
  subjects:
    - kind: ServiceAccount
      name: falco-pod-delete
      namespace: kubeless
  EOF
  cat <<EOF | kubectl apply -n kubeless -f -
  apiVersion: kubeless.io/v1beta1
  kind: Function
  metadata:
    finalizers:
      - kubeless.io/function
    generation: 1
    labels:
      created-by: kubeless
      function: delete-pod
    name: delete-pod
  spec:
    checksum: sha256:3889d9bab6b6f94b4ed20600836eb7c50abf1e56bd665c5d8482e189d1189462
    deps: |
      kubernetes>=12.0.1
    function-content-type: text
    function: |-
      from kubernetes import client,config
      config.load_incluster_config()
      def delete_pod(event, context):
          rule = event['data']['rule'] or None
          output_fields = event['data']['output_fields'] or None
          if rule and rule == "Terminal shell in container" and output_fields:
              if output_fields['k8s.ns.name'] and output_fields['k8s.pod.name']:
                  namespace = output_fields['k8s.ns.name']
                  if namespace == "default":
                      pod = output_fields['k8s.pod.name']
                      print (f"Deleting pod \"{pod}\" in namespace \"{namespace}\"")
                      client.CoreV1Api().delete_namespaced_pod(name=pod, namespace=namespace, body=client.V1DeleteOptions(grace_period_seconds=0))
    handler: delete-pod.delete_pod
    runtime: python3.7
    deployment:
      spec:
        template:
          spec:
            serviceAccountName: falco-pod-delete
EOF

  echo "Kubeless deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

fi

# Testing falco installation
if [ $RUN_TESTS -ne 0 ]; then 
  source ./tests.sh
fi

# End

END_TIME=$(date +'%Y-%m-%d %H:%M')
echo "Finishing execution at: $END_TIME" | tee -a ./logs/summary.log
echo ""
echo "To access the cluster with kubectl, set variable in your shell"
echo "# bash/zsh:"
echo "export KUBECONFIG=~/.kube/k3s.yaml"
echo "# fish:"
echo "set -x KUBECONFIG ~/.kube/k3s.yaml"
