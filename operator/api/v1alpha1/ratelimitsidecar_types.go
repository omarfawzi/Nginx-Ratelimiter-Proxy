package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"sigs.k8s.io/controller-runtime/pkg/scheme"
)

// RateLimitSidecarSpec defines the desired state of RateLimitSidecar
// +kubebuilder:object:generate=true
// +kubebuilder:resource:scope=Namespaced
// This CRD specifies a label selector for target pods
// and the rate limit configuration in YAML format.
type RateLimitSidecarSpec struct {
	Selector metav1.LabelSelector `json:"selector"`
	// Env specifies the environment variables for the sidecar container.
	// Keys correspond to the variables documented in the README, e.g. UPSTREAM_HOST.
	Env map[string]string `json:"env,omitempty"`
	// RateLimits contains the rate limit configuration.
	// The structure follows the example in the README.
	RateLimits runtime.RawExtension `json:"rateLimits"`
}

// +kubebuilder:object:root=true
// RateLimitSidecar is the Schema for the ratelimitersidecars API
// This CR controls sidecar injection for matching pods.
type RateLimitSidecar struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec RateLimitSidecarSpec `json:"spec,omitempty"`
}

func (in *RateLimitSidecar) DeepCopyInto(out *RateLimitSidecar) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	out.Spec = in.Spec
}

func (in *RateLimitSidecar) DeepCopy() *RateLimitSidecar {
	if in == nil {
		return nil
	}
	out := new(RateLimitSidecar)
	in.DeepCopyInto(out)
	return out
}

func (in *RateLimitSidecar) DeepCopyObject() runtime.Object {
	return in.DeepCopy()
}

// +kubebuilder:object:root=true
// RateLimitSidecarList contains a list of RateLimitSidecar

type RateLimitSidecarList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []RateLimitSidecar `json:"items"`
}

func (in *RateLimitSidecarList) DeepCopyInto(out *RateLimitSidecarList) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ListMeta.DeepCopyInto(&out.ListMeta)
	if in.Items != nil {
		out.Items = make([]RateLimitSidecar, len(in.Items))
		for i := range in.Items {
			in.Items[i].DeepCopyInto(&out.Items[i])
		}
	}
}

func (in *RateLimitSidecarList) DeepCopy() *RateLimitSidecarList {
	if in == nil {
		return nil
	}
	out := new(RateLimitSidecarList)
	in.DeepCopyInto(out)
	return out
}

func (in *RateLimitSidecarList) DeepCopyObject() runtime.Object {
	return in.DeepCopy()
}

// GroupVersion is group version used to register these objects
var GroupVersion = schema.GroupVersion{Group: "ratelimiter.codex", Version: "v1alpha1"}

var SchemeBuilder = &scheme.Builder{GroupVersion: GroupVersion}

func init() {
	SchemeBuilder.Register(&RateLimitSidecar{}, &RateLimitSidecarList{})
}

func AddToScheme(s *runtime.Scheme) error {
	return SchemeBuilder.AddToScheme(s)
}
