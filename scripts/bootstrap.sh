#!/bin/bash

set -e

START_TIME=$(date +'%Y-%m-%d %H:%M')
echo "Executing script for end-to-end testing of Falco Helm chart" | tee ./logs/summary.log
echo "Starting execution at: $START_TIME" | tee -a ./logs/summary.log

# Configuration

# MULTINODE: 0 -> use single node, 1 -> use 1 master 2 worker
MULTINODE=${MULTINODE:-0}

# INSTALL_KUBELESS: 0 -> no, 1 -> yes
INSTALL_KUBELESS=${INSTALL_KUBELESS:-0}

# INSTALL_SIDEKICK: 0 -> no, 1 -> yes
INSTALL_SIDEKICK=${INSTALL_SIDEKICK:-0}

# RUN_AUDIT_TESTS: 0 -> no, 1 -> yes
RUN_ADIT_TESTS=${RUN_AUDIT_TESTS:-1}

# FALCO_CHART_LOCATION: "" -> use online version , "./local_dir"  -> use local dir
FALCO_CHART_LOCATION=${FALCO_CHART_LOCATION:-""}
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

# If not set, default version is the last known working

K3S_VERSION=${K3S_VERSION:-"$K3S_WORKING"}
FALCO_CHART_VERSION=${FALCO_CHART_VERSION:-"$FALCO_CHART_WORKING"}
KUBELESS_VERSION=${KUBELESS_VERSION:-"$KUBELESS_WORKING"}
SIDEKICK_UI_VERSION=${SIDEKICK_UI_VERSION:-"$SIDEKICK_UI_WORKING"}

# If specified "latest" string as the version, replace that with the published latest

[ "$K3S_VERSION" == "latest" ] && K3S_VERSION="$K3S_LATEST"
[ "$FALCO_CHART_VERSION" == "latest" ] && FALCO_CHART_VERSION="$FALCO_CHART_LATEST"
[ "$KUBELESS_VERSION" == "latest" ] && KUBELESS_VERSION="$KUBELESS_LATEST"
[ "$SIDEKICK_UI_VERSION" == "latest" ] && SIDEKICK_UI_VERSION="$SIDEKICK_UI_LATEST"

# Prepare labels to put besides the used version to make it clear which it is

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

# Display initial configuration

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

dir="$(dirname "$(realpath "$0")")"

source "$dir"/multipass/create_cluster.sh
source "$dir"/install_falco.sh
source "$dir"/multipass/enable_auditlog.sh
source "$dir"/install_kubeless.sh

END_TIME=$(date +'%Y-%m-%d %H:%M')
echo "Finishing execution at: $END_TIME" | tee -a ./logs/summary.log
echo ""
echo "To access the cluster with kubectl, set variable in your shell"
echo "# bash/zsh:"
echo "export KUBECONFIG=./kubeconfig.yaml"
echo "# fish:"
echo "set -x KUBECONFIG ./kubeconfig.yaml"
