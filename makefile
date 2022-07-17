# Tests

all: delete-cluster bootstrap summary

all-local-chart: delete-cluster bootstrap-local-chart summary

all-latest: delete-cluster bootstrap-latest summary

# -----------------------------------------------------------------------

requirements:
	which ts
	which tee
	multipass --version
	kubectl version

# -----------------------------------------------------------------------

bootstrap:
	./bootstrap.sh

bootstrap-local-chart:
	FALCO_CHART_LOCATION="./charts/falco" ./bootstrap.sh

bootstrap-latest:
	K3S_VERSION="latest" FALCO_CHART_VERSION="latest" KUBELESS_VERSION="latest" SIDEKICK_UI_VERSION="latest" ./bootstrap.sh

# -----------------------------------------------------------------------

delete-cluster:
	multipass delete --all -p

summary:
	@echo "----------------------------------------------------------------"
	@echo "Summary:"
	cat logs/summary.log

pod_logs:
	cat logs/falco_pod.log
