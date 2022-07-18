#!/bin/bash

dir="$(dirname "$(realpath "$0")")"

# Install falco
if [ "$FALCO_CHART_LOCATION" == "" ]; then
  helm repo add falcosecurity https://falcosecurity.github.io/charts
  FALCO_CHART_LOCATION="falcosecurity/falco"
  CHART_VERSION_PARAM="--version $FALCO_CHART_VERSION"
else 
  CHART_VERSION_PARAM=""
  echo "Local Falco Helm chart dir: $FALCO_CHART_LOCATION" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
  HELM_VERSION=$(helm show chart "$FALCO_CHART_LOCATION" | yq '.version')
  echo "  chart version: $HELM_VERSION" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
  GIT_REMOTE=$(cd $FALCO_CHART_LOCATION && git config --get remote.origin.url)
  echo "  git repo remote origin: $GIT_REMOTE" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
  GIT_BRANCH=$(cd $FALCO_CHART_LOCATION && git branch --show-current)
  echo "  git branch: $GIT_BRANCH " | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
  GIT_COMMIT=$(cd $FALCO_CHART_LOCATION && git rev-parse HEAD)
  GIT_COMMIT_SHORT=$(cd $FALCO_CHART_LOCATION && git rev-parse --short HEAD)
  echo "  git commit : $GIT_COMMIT ($GIT_COMMIT_SHORT)" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
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
echo "  $INSTALL_COMMAND" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

eval $INSTALL_COMMAND
  
echo "Falco helm chart deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

kubectl apply -f "$dir"/falco_service.yaml -n falco
