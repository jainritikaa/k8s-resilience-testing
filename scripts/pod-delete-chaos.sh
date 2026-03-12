#!/bin/bash

# Colors
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

NAMESPACE="notes"
ITERATIONS=5

TOTAL_RECOVERY_TIME=0

echo -e "${CYAN}"
echo "================================================="
echo " Kubernetes Manual Pod Deletion Chaos Experiment (MTTR)"
echo "================================================="
echo -e "${RESET}"

echo -e "${BLUE}[INFO]${RESET} Target Namespace : $NAMESPACE"
echo -e "${BLUE}[INFO]${RESET} Iterations       : $ITERATIONS"
echo ""

for i in $(seq 1 $ITERATIONS)
do
    echo -e "${YELLOW}[EXPERIMENT]${RESET} Iteration $i"

    POD=$(kubectl get pods -n $NAMESPACE \
    -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | shuf -n 1)

    if [ -z "$POD" ]; then
        echo -e "${RED}[ERROR]${RESET} No pods found in namespace $NAMESPACE"
        exit 1
    fi

    echo -e "${BLUE}[INFO]${RESET} Selected Pod : $POD"

    echo -e "${YELLOW}[ACTION]${RESET} Injecting failure (Deleting pod)..."

    DELETE_TIME=$(date +%s)

    kubectl delete pod $POD -n $NAMESPACE >/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS]${RESET} Pod '$POD' deleted successfully"
    else
        echo -e "${RED}[ERROR]${RESET} Failed to delete pod"
        exit 1
    fi

    echo -e "${BLUE}[INFO]${RESET} Waiting for replacement pod to become Ready..."

    # Wait until a new pod becomes Ready
    kubectl wait --for=condition=ready pod \
    -n $NAMESPACE \
    --timeout=120s \
    $(kubectl get pods -n $NAMESPACE -o name)

    RECOVERY_TIME=$(date +%s)

    RECOVERY_DURATION=$((RECOVERY_TIME - DELETE_TIME))

    TOTAL_RECOVERY_TIME=$((TOTAL_RECOVERY_TIME + RECOVERY_DURATION))

    echo -e "${GREEN}[METRIC]${RESET} Recovery Time: ${RECOVERY_DURATION} seconds"

    echo -e "${BLUE}[INFO]${RESET} Current Pod Status:"
    kubectl get pods -n $NAMESPACE

    echo "--------------------------------------------"
done

AVG_MTTR=$((TOTAL_RECOVERY_TIME / ITERATIONS))

echo ""
echo -e "${GREEN}[COMPLETE]${RESET} Chaos Experiment Finished"
echo ""

echo -e "${CYAN}Experiment Summary${RESET}"
echo "Namespace          : $NAMESPACE"
echo "Failures Injected  : $ITERATIONS"
echo "Total Recovery Time: ${TOTAL_RECOVERY_TIME}s"
echo "Average MTTR       : ${AVG_MTTR}s"
echo "Objective          : Evaluate Kubernetes self-healing capability"
echo ""