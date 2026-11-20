.RECIPEPREFIX = >
CLUSTER ?= payments
NS ?= payments
CALICO_VERSION ?= v3.31.0

.PHONY: up cluster cni metrics-server secret deploy smoke port-forward chaos down

up: cluster cni metrics-server secret deploy smoke

cluster:
> kind get clusters | grep -qx $(CLUSTER) || kind create cluster --name $(CLUSTER) --config kind/cluster.yaml

cni:
> kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/$(CALICO_VERSION)/manifests/calico.yaml
> kubectl -n kube-system rollout status ds/calico-node --timeout=240s
> kubectl wait --for=condition=Ready nodes --all --timeout=240s

metrics-server:
> kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
> kubectl -n kube-system patch deploy metrics-server --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

secret:
> kubectl create ns $(NS) --dry-run=client -o yaml | kubectl apply -f -
> kubectl -n $(NS) get secret service-token >/dev/null 2>&1 || kubectl -n $(NS) create secret generic service-token --from-literal=SERVICE_TOKEN=$$(openssl rand -hex 32)

deploy:
> kubectl apply -k k8s/base
> kubectl -n $(NS) rollout status deploy/payment-processor --timeout=180s
> kubectl -n $(NS) rollout status deploy/payment-gateway --timeout=180s

smoke:
> kubectl -n $(NS) port-forward svc/payment-gateway 8080:80 >/dev/null 2>&1 & PF=$$!; sleep 3; BASE=http://localhost:8080 ./scripts/smoke.sh; RC=$$?; kill $$PF; exit $$RC

port-forward:
> kubectl -n $(NS) port-forward svc/payment-gateway 8080:80

chaos:
> kubectl apply -k k8s/overlays/chaos
> kubectl -n $(NS) rollout restart deploy

down:
> kind delete cluster --name $(CLUSTER)
