# Targets of interest
# deploy - the main target you use to deploy to 
APP_REPOSITORY       = perceptilabs-operator-package
APP_REGISTRY_API     = https://quay.io/cnr/api/v1/packages
DOCKER_SERVER        = perceptilabs.azurecr.io
DOCKER_USERNAME      = perceptilabs
REGISTRY             = quay.io
REGISTRY_ACCOUNT     = perceptilabs
SERVICEACCOUNT_NAME  = perceptilabs-operator-sa
GPU_COUNT           ?= 0
TEMPLATE_CMD         = @sed 's+REPLACE_NAMESPACE+${NAMESPACE}+g; s+REPLACE_SERVICEACCOUNT_NAME+${SERVICEACCOUNT_NAME}+g; s+REPLACE_GPU_COUNT+${GPU_COUNT}+g'
TOOLS_DIR            = tools

require-%:
	@: $(if ${${*}},,$(error You must pass the $* environment variable))

install-custom-operator: ## Install the custom OperatorSource from the repos to the cluster
	@${TOOLS_DIR}/check-quay ${APP_REGISTRY_API}/${REGISTRY_ACCOUNT}/${APP_REPOSITORY}
	@oc apply -f ${TOOLS_DIR}/operator-source.yaml
	@${TOOLS_DIR}/wait_for_log "openshift-marketplace" "perceptilabs-operators-" "serving registry" "perceptilabs-operators" &>/dev/null
	@echo operator pod is running

namespace: require-NAMESPACE
	@${TEMPLATE_CMD} ${TOOLS_DIR}/namespace.yaml | oc apply -f -

serviceaccount: require-SERVICEACCOUNT_NAME
	@${TEMPLATE_CMD} ${TOOLS_DIR}/sa.yaml | oc apply -f -

persistentvolume: namespace ## Create the persistent volume needed for core
	@${TEMPLATE_CMD} ${TOOLS_DIR}/persistentvolume.yaml | oc apply -f -

subscription: install-custom-operator persistentvolume namespace serviceaccount
	@${TEMPLATE_CMD} ${TOOLS_DIR}/subscription.yaml | oc apply -f -
	@"${TOOLS_DIR}/wait_for_log" "${NAMESPACE}" "perceptilabs-operator-" "starting to serve" "operator"

instance: subscription ## Install perceptilabs in NAMESPACE
	@${TEMPLATE_CMD} ${TOOLS_DIR}/start-instance.yaml | oc apply -f -

frontend-route: frontend-pod ## Get the frontend route for perceptilabs in NAMESPACE
	@$(eval FRONTEND_URL="http://$(shell ${TOOLS_DIR}/get_live_route ${NAMESPACE} perceptilabs-frontend)")
	$(info Route is serving at ${FRONTEND_URL})

core-pod: instance
	@${TOOLS_DIR}/get_running_pod ${NAMESPACE} perceptilabs-core- | tail -n 1
	@$(eval CORE_POD=$(shell ${TOOLS_DIR}/get_running_pod ${NAMESPACE} perceptilabs-core- | tail -n 1))

core-route: core-pod
	@$(eval CORE_URL="http://$(shell ${TOOLS_DIR}/get_live_route ${NAMESPACE} perceptilabs-core)")

frontend-pod: instance
	@${TOOLS_DIR}/get_running_pod ${NAMESPACE} perceptilabs-frontend- | tail -n 1

valid-storage: core-pod
	@oc cp README.md --namespace=${NAMESPACE} ${CORE_POD}:/mnt/plabs --container=core

deploy: valid-storage core-route frontend-route ## Deploy and check the perceptilabs operator to the cluster and print the frontend route

deploy-for-test: frontend-route core-route
	$(info copying test data to ${CORE_POD})
	@ls test_data | xargs -L 1 -I {} oc cp test_data/{} --namespace ${NAMESPACE} ${CORE_POD}:/mnt/plabs --container=core
	@open ${FRONTEND_URL}

clean-namespace: require-NAMESPACE ## Remove the installed namespace and everything in it
	${TEMPLATE_CMD} ${TOOLS_DIR}/namespace.yaml | oc delete --ignore-not-found -f -

clean-storage: require-NAMESPACE ## Remove the persistent volume
	${TEMPLATE_CMD} ${TOOLS_DIR}/persistentvolume.yaml | oc delete --ignore-not-found -f -

# TODO: this is a bit clunky since you have to delete one (and only one) namespace along with the operator
clean-cluster: clean-namespace clean-storage ## Remove all perceptilabs-related objects from the cluster
	@${TEMPLATE_CMD} ${TOOLS_DIR}/operator-source.yaml | oc delete --ignore-not-found -f -
	@oc delete customresourcedefinitions perceptilabs.perceptilabs.com --ignore-not-found

# script-kiddied from https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.DEFAULT_GOAL := help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: clean-cluster clean-namespace clean-storage deploy install-custom-operator instance persistentvolume frontend-route

