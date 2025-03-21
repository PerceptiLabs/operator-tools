# Targets of interest
# deploy - the main target you use to deploy to 
APP_NAME             = perceptilabs-operator
APP_REPOSITORY       = ${APP_NAME}-package
REGISTRY_ACCOUNT     = perceptilabs
REGISTRY_REPO        = quay.io/perceptilabs/perceptilabs-operator-registry
GPU_COUNT           ?= 0
TEMPLATE_CMD         = @sed 's+REPLACE_NAMESPACE+${NAMESPACE}+g; s+REPLACE_GPU_COUNT+${GPU_COUNT}+g; s+REPLACE_SUBSCRIPTION_NAME+${APP_REPOSITORY}+g'
TOOLS_DIR            = tools
CLUSTER_PROVIDER     = $(shell oc get nodes -o custom-columns=x:spec.providerID --no-headers | cut -d: -f1 | uniq)

require-%:
	@: $(if ${${*}},,$(error You must pass the $* environment variable))

install-custom-operator: require-REGISTRY_VERSION ## Install the custom OperatorSource from the repos to the cluster
	@sed 's+REPLACE_REGISTRY_REPO+${REGISTRY_REPO}:${REGISTRY_VERSION}+g' ${TOOLS_DIR}/catalog-source.yaml | oc apply -f -
	@${TOOLS_DIR}/wait_for_log "openshift-marketplace" "perceptilabs-operators-" "serving registry" "registry-server" &>/dev/null
	@echo operator pod is running

namespace: require-NAMESPACE
	@${TEMPLATE_CMD} ${TOOLS_DIR}/namespace.yaml | oc apply -f -

persistentvolume: namespace ## Create the persistent volume needed for core
	$(info Creating storage class for cluster provider "${CLUSTER_PROVIDER}")
	@oc apply -f ${TOOLS_DIR}/storage-class-${CLUSTER_PROVIDER}.yaml
	@oc apply -n ${NAMESPACE} -f ${TOOLS_DIR}/persistentvolumeclaim.yaml

subscription: install-custom-operator namespace
	@${TEMPLATE_CMD} ${TOOLS_DIR}/subscription.yaml | oc apply -f -
	@"${TOOLS_DIR}/wait_for_log" "${NAMESPACE}" "perceptilabs-operator-" "starting to serve" "operator"

instance: subscription persistentvolume ## Install perceptilabs in NAMESPACE
ifeq (${GPU_COUNT}, 0)
	@oc apply --namespace=${NAMESPACE} -f ${TOOLS_DIR}/start-instance-demo.yaml
else
	@${TEMPLATE_CMD} ${TOOLS_DIR}/start-instance-gpu.yaml | oc apply -f -
endif

frontend-pod: instance
	@${TOOLS_DIR}/get_running_pod ${NAMESPACE} perceptilabs-frontend- | tail -n 1

rygg-pod: instance
	@${TOOLS_DIR}/get_running_pod ${NAMESPACE} perceptilabs-rygg- | tail -n 1

core-pod: instance
	@${TOOLS_DIR}/get_running_pod ${NAMESPACE} perceptilabs-core- | tail -n 1
	@$(eval CORE_POD=$(shell ${TOOLS_DIR}/get_running_pod ${NAMESPACE} perceptilabs-core- | tail -n 1))

frontend-route: frontend-pod ## Get the frontend route for perceptilabs in NAMESPACE
	@$(eval FRONTEND_URL="http://$(shell ${TOOLS_DIR}/get_live_route ${NAMESPACE} perceptilabs-frontend)")
	$(info Route is serving at ${FRONTEND_URL})

rygg-route: frontend-pod ## Get the frontend route for perceptilabs in NAMESPACE
	@$(eval RYGG_URL="http://$(shell ${TOOLS_DIR}/get_live_route ${NAMESPACE} perceptilabs-rygg)")

core-route: core-pod
	@$(eval CORE_URL="http://$(shell ${TOOLS_DIR}/get_live_route ${NAMESPACE} perceptilabs-core)")

valid-storage: core-pod
	@oc cp README.md --namespace=${NAMESPACE} ${CORE_POD}:/mnt/plabs --container=core

deploy-from-quay: valid-storage core-route frontend-route rygg-route ## Deploy and check the perceptilabs operator to the cluster and print the frontend route

deploy-for-test: frontend-route core-route rygg-route ## deploy from quay and upload MNIST data for testing
	${TOOLS_DIR}/upload_test_data
	@open ${FRONTEND_URL}

deploy-from-operatorhub: namespace ## Deploy from the operatorhub
	@oc apply --namespace=${NAMESPACE} -f ${TOOLS_DIR}/hub-prereqs.yaml
	@read -p "Now you can go to the OperatorHub and install PerceptiLabs to ${NAMESPACE}. Press enter when it's installed"
	@${TOOLS_DIR}/upload_test_data

clean-namespace: require-NAMESPACE ## Remove the installed namespace and everything in it
	${TEMPLATE_CMD} ${TOOLS_DIR}/namespace.yaml | oc delete --ignore-not-found -f -

clean-storage: require-NAMESPACE ## Remove the persistent volume
	@oc delete --ignore-not-found --namespace=${NAMESPACE} -f ${TOOLS_DIR}/persistentvolumeclaim.yaml
	@oc delete --ignore-not-found -f ${TOOLS_DIR}/storage-class-${CLUSTER_PROVIDER}.yaml

# TODO: this is a bit clunky since you have to delete one (and only one) namespace along with the operator
clean-cluster: clean-namespace clean-storage ## Remove all perceptilabs-related objects from the cluster
	oc delete catalogsource -n openshift-marketplace perceptilabs-operators
	@oc delete customresourcedefinitions perceptilabs.perceptilabs.com --ignore-not-found

remove-nvidia: ## Remove the Nvidia operator from the cluster
	@${TOOLS_DIR}/remove-nvidia

deploy-nvidia: ## Deploy the Nvidia operator to the cluster and wait for it to annotate a node
	@${TOOLS_DIR}/deploy-nvidia

redeploy-nvidia: remove-nvidia deploy-nvidia ## Remove and Deploy the Nvidia operator.

# script-kiddied from https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.DEFAULT_GOAL := help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: clean-cluster clean-namespace clean-storage deploy install-custom-operator instance persistentvolume frontend-route

