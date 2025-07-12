package controllers

import (
	"context"
	"encoding/json"

	v1 "github.com/example/ratelimiter-operator/api/v1alpha1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/yaml"
)

const sidecarName = "ratelimiter-proxy"

// RateLimitSidecarReconciler reconciles RateLimitSidecar objects

type RateLimitSidecarReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *RateLimitSidecarReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	l := log.FromContext(ctx)
	var rl v1.RateLimitSidecar
	if err := r.Get(ctx, req.NamespacedName, &rl); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	selector, err := metav1.LabelSelectorAsSelector(&rl.Spec.Selector)
	if err != nil {
		l.Error(err, "invalid selector")
		return ctrl.Result{}, nil
	}

	var pods corev1.PodList
	if err := r.List(ctx, &pods, &client.ListOptions{Namespace: rl.Namespace, LabelSelector: selector}); err != nil {
		return ctrl.Result{}, err
	}

	for i := range pods.Items {
		pod := &pods.Items[i]
		if hasSidecar(pod) {
			continue
		}
		env := []corev1.EnvVar{{Name: "CACHE_PREFIX", Value: rl.Namespace}}
		for k, v := range rl.Spec.Env {
			env = append(env, corev1.EnvVar{Name: k, Value: v})
		}

		pod.Spec.Containers = append(pod.Spec.Containers, corev1.Container{
			Name:  sidecarName,
			Image: "ratelimiter-proxy:latest",
			Env:   env,
			VolumeMounts: []corev1.VolumeMount{{
				Name:      "ratelimit-config",
				MountPath: "/usr/local/openresty/nginx/lua/ratelimits.yaml",
				SubPath:   "ratelimits.yaml",
			}},
		})
		addConfigVolume(pod, rl.Name)
		if err := r.Update(ctx, pod); err != nil {
			l.Error(err, "unable to update pod", "pod", pod.Name)
		}
	}

	cm := &corev1.ConfigMap{ObjectMeta: metav1.ObjectMeta{Name: rl.Name + "-config", Namespace: rl.Namespace}}
	if _, err := ctrl.CreateOrUpdate(ctx, r.Client, cm, func() error {
		raw, err := json.Marshal(rl.Spec.RateLimits)
		if err != nil {
			return err
		}
		yamlData, err := yaml.JSONToYAML(raw)
		if err != nil {
			return err
		}
		cm.Data = map[string]string{"ratelimits.yaml": string(yamlData)}
		return ctrl.SetControllerReference(&rl, cm, r.Scheme)
	}); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *RateLimitSidecarReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&v1.RateLimitSidecar{}).
		Complete(r)
}

func hasSidecar(pod *corev1.Pod) bool {
	for _, c := range pod.Spec.Containers {
		if c.Name == sidecarName {
			return true
		}
	}
	return false
}

func addConfigVolume(pod *corev1.Pod, configName string) {
	for _, v := range pod.Spec.Volumes {
		if v.Name == "ratelimit-config" {
			return
		}
	}
	pod.Spec.Volumes = append(pod.Spec.Volumes, corev1.Volume{
		Name: "ratelimit-config",
		VolumeSource: corev1.VolumeSource{
			ConfigMap: &corev1.ConfigMapVolumeSource{LocalObjectReference: corev1.LocalObjectReference{Name: configName + "-config"}},
		},
	})
}
