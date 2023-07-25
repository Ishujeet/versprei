import logging
import os
from .kube_utils import get_pod_distribution_with_labels, get_pods_for_deployment
logging.basicConfig(
    format="%(asctime)s %(levelname)s: %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)

DistributionSpec = [
    {
        "nodeLabel": "type=spotnew",
        "weight": 50
    },
    {
        "nodeLabel": "type=spotnew2",
        "weight": 50
    }
]

def get_percentage_of_running_pods_by_node_selector(list_of_running_pods, nodelabels, spread_node_label):
    total_running_pods = 0
    for pod in list_of_running_pods:
        if pod["nodeSelector"] in nodelabels:
            total_running_pods += 1
        else:
            continue
    pod_count = 0
    for pod in list_of_running_pods:
        if spread_node_label == pod["nodeSelector"]:
            pod_count += 1
    try:
        percentage = (pod_count/total_running_pods)*100
    except ZeroDivisionError:
        percentage = 0
    return percentage
    


def get_node_selector_patch(deployment_name):
    
    # Setting default for testing
    if os.getenv('ENV') == "dev":
        distribution_spec = DistributionSpec
    else:
        distribution_spec = get_pod_distribution_with_labels(deployment_name=deployment_name)

    # Distribution spec not found then Ignore patching
    if os.getenv('ENV') != "dev" and distribution_spec == "Not Found":
        return None
    list_of_running_pods = get_pods_for_deployment(
        deployment_name=deployment_name)
    
    # If running pods not found for deployment
    # either first deployment or not pods running for deployment
    # then just patch first pod for distribution spec node label
    if list_of_running_pods == []:
        for d in distribution_spec:
            key = d["nodeLabel"].split("=")[0]
            value = d["nodeLabel"].split("=")[1]
            node_selector = {key: value}
            logger.info(f"Patching deployment {deployment_name} with nodeSelector {node_selector}")
            return node_selector
    else:
        nodelables = []
        for d in distribution_spec:
            nodelables.append(d["nodeLabel"])
        for d in distribution_spec:
            # Get percentage of pods for nodelabel 
            weight = get_percentage_of_running_pods_by_node_selector(
                list_of_running_pods=list_of_running_pods, nodelabels=nodelables, spread_node_label=d["nodeLabel"])
            logger.info(f"Current weight of pods with node label {d['nodeLabel']} is {weight}")
            # If weight of the nodelabel is greater than
            # wieght set in distribution spec nodelabel,
            # don't patch it 
            if weight > d["weight"]:
                logger.info(f"Current weight {weight} is greater than distribution weight {d['weight']}")
                continue
            else:
                key = d["nodeLabel"].split("=")[0]
                value = d["nodeLabel"].split("=")[1]
                node_selector = {key: value}
                logger.info(f"Patching deployment {deployment_name} with nodeSelector {node_selector}")
                return node_selector