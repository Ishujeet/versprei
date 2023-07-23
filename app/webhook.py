import json
import base64
import logging
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from .utils import get_node_selector_patch

logging.basicConfig(
    format="%(asctime)s %(levelname)s: %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()


@app.get("/health")
def health():
    return "OK"


@app.post('/mutate')
async def mutate_pod(req: Request):
    admission_review = await req.json()

    # Ignore if request is not for pod creation
    if admission_review['request']['kind']['kind'] != 'Pod':
        logger.info("This admission webhook only handles pod creation requests")
        return JSONResponse(content={'apiVersion': admission_review['apiVersion'], 'kind': 'AdmissionReview', 'response': {
            'allowed': True, 'uid': admission_review['request']['uid']}})

    # Ignore pods created by Jobs
    if 'job-name' in admission_review['request']['object']['metadata']['labels']:
        logger.info("Ignoring pods created by Job")
        return JSONResponse(content={'apiVersion': admission_review['apiVersion'], 'kind': 'AdmissionReview', 'response': {
            'allowed': True, 'uid': admission_review['request']['uid']}})

    deployment_name = admission_review['request']["object"]["metadata"]["labels"]["app"]
    logger.info(f"Got the request for deployment {deployment_name}")
    
    # Get node selector patch fro a pod spec on the distribution provided
    # in poddistributor object for the deployment
    node_selector = get_node_selector_patch(deployment_name)

    # Ignore pods which doesn't have pod_distribution set
    if node_selector is None:
        logger.info(f"Pod distribution not specified for deployment {deployment_name}, ignoring it.")
        return JSONResponse(content={'apiVersion': admission_review['apiVersion'], 'kind': 'AdmissionReview', 'response': {
            'allowed': True, 'uid': admission_review['request']['uid']}})
    else:
        metadata = admission_review['request']['object']['metadata']
        if 'annotations' not in metadata:
            logger.info("Adding an annotations field in pod spec metadata")
            metadata['annotations'] = {}

        # Add a patch indicating that the pod was mutated by this admission webhook
        metadata['annotations']['mutated-by'] = 'spread-webhook-service'
        mutation_patch = {"op": "replace", "path": "/metadata", "value": metadata}

        # Add a patch for nodeselector
        node_selector_patch = {"op": "replace", "path": "/spec/nodeSelector", "value": node_selector}
        
        # Encode the mutated pod object and return it in the response
        patch = [mutation_patch, node_selector_patch]
        encoded_patch = base64.b64encode(
            json.dumps(patch).encode('utf-8')).decode('utf-8')
        response_body = {'apiVersion': admission_review['apiVersion'], 'kind': 'AdmissionReview', 'response': {
            'allowed': True, 'uid': admission_review['request']['uid'], 'patchType': 'JSONPatch', 'patch': encoded_patch}}
        return JSONResponse(content=response_body)
