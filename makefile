# Tests

all: delete-cluster bootstrap tests summary

all-local-chart: delete-cluster bootstrap-local-chart tests summary

all-latest: delete-cluster bootstrap-latest tests summary

# -----------------------------------------------------------------------

requirements:
	which ts
	which tee
	multipass --version
	kubectl version

# -----------------------------------------------------------------------

bootstrap:
	./scripts/bootstrap.sh

bootstrap-local-chart:
	FALCO_CHART_LOCATION="./charts/falco" ./scripts/bootstrap.sh

bootstrap-latest:
	K3S_VERSION="latest" FALCO_CHART_VERSION="latest" KUBELESS_VERSION="latest" SIDEKICK_UI_VERSION="latest" ./scripts/bootstrap.sh


# -----------------------------------------------------------------------

tests:
	 ./scripts/tests.sh

tests-noaudit:
	 TEST_AUDIT=0 ./scripts/tests.sh

# -----------------------------------------------------------------------

delete-cluster:
	multipass delete --all -p

summary:
	@echo "----------------------------------------------------------------"
	@echo "Summary:"
	cat logs/summary.log

pod_logs:
	cat logs/falco_pod.log
