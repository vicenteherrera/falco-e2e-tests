# Tests

all: delete-cluster bootstrap summary

delete-cluster:
	multipass delete --all -p

bootstrap:
	./bootstrap.sh

summary:
	cat logs/summary.log

pod_logs:
	cat logs/falco_pod.log
