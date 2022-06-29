#!/bin/bash

set -e

START_TIME=$(date +'%Y-%m-%d %H:%M')
echo "Starting tests at $START_TIME" | tee -a ./logs/summary.log

LABEL_APP_KEY=$(kubectl get ds falco -n falco -oyaml | yq '.metadata.labels' | grep -v 'instance' | grep 'falco' | grep 'app' | yq '. | keys' | cut -c 3-)
echo "Using label key for selector: $LABEL_APP_KEY"
echo "Waiting for Falco pods to be ready, timeout 120s"
EXIT_CODE=1
kubectl wait pods -n falco -l $LABEL_APP_KEY=falco --for condition=Ready --timeout=120s || EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "[ FAIL ]: Falco pods ready" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
else
  echo "[  OK  ]: Falco pods ready" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
fi

echo "Checking Falco service"
TEST_SVC=$(kubectl get svc falco -n falco 2>/dev/null ||:)
if [ "$TEST_SVC" != "" ]; then
  echo "[  OK  ]: Falco service deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
else
  echo "[ FAIL ]: Falco service not deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
fi

echo "Attaching to pod Falco"
TEST_START=$(date +'%Y-%m-%dT%H:%M:%SZ' --utc)
kubectl exec -it daemonset/falco -n falco -- ls 1>/dev/null
echo -n "Checking runtime detection"
MATCH="Notice Attach/Exec to pod (user=system:admin pod=falco-"
TEST_EXEC=$(kubectl logs daemonset/falco -n falco --since-time="$TEST_START" | tee logs/detect_runtime.log | grep "$MATCH" ||:)
I=20
while [ $I -ne 0 ] && [ "$TEST_EXEC" == "" ]; do
  sleep 3
  TEST_EXEC=$(kubectl logs daemonset/falco -n falco --since-time="$TEST_START" | tee logs/detect_runtime.log | grep "$MATCH" ||:)
  let I=I-1
  echo -n "."
done
echo ""
if [ "$TEST_EXEC" != "" ]; then
  echo "[  OK  ]: Detect attach/exec to pod" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
else
  echo "[ FAIL ]: Detect attach/exec to pod" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
fi

echo "Cleaning up possible debug pod"
kubectl delete pod debug -n kube-system 2>/dev/null ||:

echo "Launching pod in kube-system"
TEST_START=$(date +'%Y-%m-%dT%H:%M:%SZ' --utc)
kubectl run -it --rm --restart=Never debug -n kube-system --image alpine -- ls 1>/dev/null
echo -n "Checking kube audit detection"
MATCH="Warning Pod created in kube namespace (user=system:admin pod=debug ns=kube-system images=alpine)"
TEST_AUDIT=$(kubectl logs daemonset/falco -n falco --since-time="$TEST_START" | tee logs/detect_audit.log | grep "$MATCH" ||:)
I=20
while [ $I -ne 0 ] && [ "$TEST_AUDIT" == "" ]; do
  sleep 3
  TEST_AUDIT=$(kubectl logs daemonset/falco -n falco --since-time="$TEST_START" | tee logs/detect_audit.log | grep "$MATCH" ||:)
  let I=I-1
  echo -n "."
done
echo ""
if [ "$TEST_AUDIT" != "" ]; then
  echo "[  OK  ]: Detect pod created in kube namespace" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
else
  echo "[ FAIL ]: Detect pod created in kube namespace" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
fi

echo "Tests finished"
