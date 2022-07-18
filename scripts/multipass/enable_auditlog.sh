#!/bin/bash



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

echo "Waiting control plane to be ready again"
TEST_EXEC=""
I=10
while [ $I -ne 0 ] && [ "$TEST_EXEC" == "" ]; do
  sleep 3
  TEST_EXEC=$(kubectl get nodes 2>/dev/null ||:)
  let I=I-1
  echo -n "."
done
if [ "$TEST_EXEC" == "" ]; then
  echo "Control plane not available"
  exit 1
fi

echo "Kubernetes audit log instrumentation deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
