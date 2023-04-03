/*
Copyright 2023.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1beta1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

type Target struct {
	// Name of the deployment
	Name string `json:"name"`

	// Api version of deployment
	APIVersion string `json:"apiVersion,omitempty"`

	// Deployment
	Kind string `json:"kind,omitempty"`
}

type Distribution struct {
	// Label of nodes
	NodeLabel metav1.LabelSelector `json:"nodeLabel"`

	// Percentage of pods needs to be schedule, max is 100
	Weight int32 `json:"weight"`
}

// PodDistributorSpec defines the desired state of PodDistributor
type PodDistributorSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Distribution specifies the node and % of pods according which
	// pod distribution should happen
	Distribution Distribution `json:"distribution"`

	// Target specifies the deployment target
	Target Target `json:"target"`
}

// PodDistributorStatus defines the observed state of PodDistributor
type PodDistributorStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	TargetKind string `json:"scaleTargetKind,omitempty"`
	Status     string `json:"status,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// PodDistributor is the Schema for the poddistributors API
type PodDistributor struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   PodDistributorSpec   `json:"spec,omitempty"`
	Status PodDistributorStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// PodDistributorList contains a list of PodDistributor
type PodDistributorList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []PodDistributor `json:"items"`
}

func init() {
	SchemeBuilder.Register(&PodDistributor{}, &PodDistributorList{})
}
