# Versprei

![Logo](https://github.com/Ishujeet/versprei/blob/master/logo.png)

### Built With

* [Custom Resource Definition][crds-url]
* [Mutating Webhook Configuration][mwc-url]
* [Python][python-url]
* [FastApi][fastapi-url]
* [K8s Python Library][k8s-python-url]

### Description

The GitHub project is an innovative and efficient solution for distributing pods in Kubernetes clusters based on specific node labels and user-defined percentages. Leveraging the power of Custom Resource Definitions (CRDs), a Mutating Webhook, and FastAPI, this project streamlines the process of optimizing pod placement to enhance resource utilization and workload distribution.

### Features
* **Custom Resource Definitions (CRDs):** The project utilizes Kubernetes CRDs to define custom resources that allow users to specify their pod distribution preferences.

* **Mutating Webhook:** With the help of a Mutating Webhook, the project dynamically intercepts pod creations and mutations ensuring automatic adjustments to adhere to the specified distribution criteria.

* **FastAPI App:** A FastAPI web application serves as the control plane for users to configure pod distribution rules conveniently and monitor their application's pod allocation.

### How It Works
1. **Define Distribution Rules:** Users can define their desired node labels and the corresponding percentages for pod distribution through the CRD configuration.

2. **Pod Creation or Mutation:** Whenever a pod is created or updated, the Mutating Webhook is triggered, intercepting the request.

3. **Distribution Logic:** The FastAPI app processes the request, intelligently assigning the pod to an appropriate node based on the defined distribution rules and percentages.

4. **Efficient Resource Utilization:** By distributing pods across nodes strategically, the project optimizes resource utilization and ensures workload distribution for enhanced performance.

### Benefits
* **Automated Pod Distribution:** The project eliminates the need for manual pod assignment, reducing the operational burden and minimizing human errors.

* **Flexible Configuration:** Users have the flexibility to set custom distribution rules based on their specific application requirements.

* **Dynamic Adjustments:** As the cluster evolves and the node conditions change, the Mutating Webhook automatically adjusts pod placement, ensuring ongoing optimization.

* **Resource Optimization**: By efficiently utilizing node resources, the project helps prevent resource imbalances and ensures better cluster performance.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

* Ensure that MutatingAdmissionWebhook and ValidatingAdmissionWebhook admission controllers are enabled. [Here][ac-url] is a recommended set of admission controllers to enable in general.
* Ensure that the admissionregistration.k8s.io/v1 API is enabled.
* Ensure that [kubectl][kubectl-url] is installed

### Installation

#### Easy Install
1. Clone the repo
   ```sh
   git clone git@bitbucket.org:c4hybris/pod-spread-webhook.git
   ```
2. Build the image locally and deploy to local cluster with required CRD's, Mutating Webhook, and Webhook Service/App.
   ```sh
   make install
   ```
3. Deploy a test app in cluster by name of nginx-deployment with required PodDistributor object which specify weight distribution for pods placement.
   ```sh
   make test
   ```
4. To clean/delete all the resources created using above commands.
   ```sh
   make clean
   ```

#### Manual Install
1. CLone the repo
   ```sh
   git clone git@bitbucket.org:c4hybris/pod-spread-webhook.git
   ```
2. Install CRD's
   ```sh
   kubectl apply -f config/crd/
   ```
3. Install Mutating Webhook Configuration
   ```sh
   kubectl apply -f config/webhook/
   ```
   #### Note:
   Mutating Webhook needs a CA Bundle to communicate to webhook services, as all the communication happens in k8s is over https. Here I am using a self signed certifcate which you can find under certs folder.

4. Apply RBAC, these will be used by webhook service to get poddistributor and deployment specs.
   ```sh
   kubectl apply -f config/rbac/
   ```
5. Install webhook service which get the request from mutating webhook integration.
   ```sh
   kubectl apply -f config/deploy
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->
### Usage

Below PodDistributor object will specify weight distribution of the pods for specific deployment based on node labels.
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