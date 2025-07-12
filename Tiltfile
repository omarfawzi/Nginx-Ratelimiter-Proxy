docker_build('ratelimiter-operator', '.', dockerfile='operator.Dockerfile')

k8s_yaml(['operator/config/crd.yaml', 'operator/config/rbac.yaml', 'operator/config/deployment.yaml'])

k8s_resource('ratelimiter-operator', port_forwards=9443)
