#!/bin/bash


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
