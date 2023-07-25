# Versprei

![https://github.com/ishujeet/versprei/logo.gif](https://github.com/Ishujeet/versprei/blob/master/logo.png)


<!-- TABLE OF CONTENTS -->
##### Table of Contents
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
  </ol>



<!-- ABOUT THE PROJECT -->
## About The Project

Pod spreader webhook is mutating webhook service which helps in scheduling pods on different nodes based on the node labels in Kubernetes.

### Built With

* [Custom Resource Definition][crds-url]
* [Mutating Webhook Configuration][mwc-url]
* [Python][python-url]
* [FastApi][fastapi-url]
* [K8s Python Library][k8s-python-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

* Ensure that MutatingAdmissionWebhook and ValidatingAdmissionWebhook admission controllers are enabled. [Here][ac-url] is a recommended set of admission controllers to enable in general.
* Ensure that the admissionregistration.k8s.io/v1 API is enabled.
* Ensure that [kubectl][kubectl-url] is installed

### Installation

1. Clone the repo
   ```sh
   git clone git@bitbucket.org:c4hybris/pod-spread-webhook.git
   ```
2. Install in k8s    
   ```sh
   make install
   ```
3. Test on a sample app
   ```sh
   make test
   ```
4. Unistall everything
   ```sh
   make clean
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage

Below PodDistributor object will specify wieght distribution on the nodes based on node labels and also specify the target deployment.
```yaml
---
apiVersion: versprei.versprei.io/v1beta1
kind: PodDistributor
metadata:
  name: nginx-deployment
  namespace: default
spec:
  distribution:
  - nodeLabel:
      type: default
    weight: 80
  - nodeLabel:
      type: spot
    weight: 20
  target:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
```

Here we reading that object and applying the patch on nodes once we recieve the request from admission controller.
```python
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
```
```python
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
    # logger.info(admission_review)
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
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[crds-url]: https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/
[mwc-url]: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.27/#mutatingwebhookconfiguration-v1-admissionregistration-k8s-io
[python-url]: https://www.python.org/
[fastapi-url]: https://fastapi.tiangolo.com/lo/
[k8s-python-url]: https://github.com/kubernetes-client/python
[kubectl-url]: https://kubernetes.io/docs/tasks/tools/#kubectl
[ac-url]: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#is-there-a-recommended-set-of-admission-controllers-to-use