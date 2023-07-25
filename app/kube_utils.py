import logging
from pprint import pprint
from kubernetes import client, config
from kubernetes.client.rest import ApiException
logging.basicConfig(
    format="%(asctime)s %(levelname)s: %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)

config.load_incluster_config()

PodDistributorGroup = "versprei.versprei.io"
PodDistributorVersion = "v1beta1"
PodDistributorPlural = "poddistributors"

def get_pod_distribution_with_labels(deployment_name):
    api_instance = client.CustomObjectsApi()
    label_selector=f"app={deployment_name}"
    try:
        api_response = api_instance.list_namespaced_custom_object(
            group=PodDistributorGroup,
            version=PodDistributorVersion,  # Replace with the appropriate version of your custom object
            namespace="default",
            plural=PodDistributorPlural,
            label_selector=label_selector,
        )
        if len(api_response.get('items', [])) > 0:
            for d in api_response.get('items', []):
                if d.get("target").get("name") == deployment_name:
                    pod_distribution = []
                    for spec in d:
                        for k, v in spec['nodeLabel'].items():
                            nodeLabel = f"{k}={v}"
                        pod_distribution.append({"nodeLabel": nodeLabel, 'weight': spec['weight']})
                    return pod_distribution
            return "Not Found"
        else:
            return "Not Found"
    except ApiException as e:
        if e.status == 404:
            return "Not Found"
        if e.status == 403:
            return "Not Found"
        logger.exception("Exception when calling CustomObjectsApi->get_namespaced_custom_object: %s\n" % e)
        return "Not Found"

def get_pod_distribution(deployment_name):
    api_instance = client.CustomObjectsApi()
    
    # Get distribution spec for deployment
    try:
        api_response = api_instance.get_namespaced_custom_object(
        group=PodDistributorGroup, version=PodDistributorVersion, namespace="default", plural=PodDistributorPlural, name=deployment_name)
        pod_distribution = []
        for d in api_response['spec']['distribution']:
            for k, v in d['nodeLabel'].items():
                nodeLabel = f"{k}={v}"
            pod_distribution.append({"nodeLabel": nodeLabel, 'weight': d['weight']})
        return pod_distribution
    except ApiException as e:
        if e.status == 404:
            return "Not Found"
        if e.status == 403:
            return "Not Found"
        logger.exception("Exception when calling CustomObjectsApi->get_namespaced_custom_object: %s\n" % e)
        return "Not Found"
    
def get_pods_for_deployment(deployment_name):
    api_instance = client.CoreV1Api()
    label_selector = f'app={deployment_name}'
    
    # Get pods for the deployment
    try:
        api_response = api_instance.list_namespaced_pod(
            namespace="default", label_selector=label_selector, watch=False)
    except ApiException as e:
        if e.status == 404:
            logger.info(f"Pods not found for {deployment_name}")
            return []
        if e.status == 403:
            logger.info(f"Access denied to get Pods for {deployment_name}")
            return []
        logger.exception(
            "Exception when calling AppsV1Api->list_namespaced_pod: %s\n" % e)
        return []
    
    pods = api_response.to_dict()['items']
    # If no pods running retrun not found
    if len(pods) == 0:
        return []
    
    list_of_pods = []
    for pod in pods:
        for k, v in pod["spec"]["node_selector"].items():
            pod_info = {"name": pod['metadata']['name'], "nodeSelector": f'{k}={v}'}
        list_of_pods.append(pod_info)
    return list_of_pods