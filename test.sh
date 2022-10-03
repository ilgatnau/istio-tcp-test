
kubectl create namespace istio-operator
cd istio-1.15.1
helm install istio-operator manifests/charts/istio-operator \
 -n istio-operator

cd ..
kubectl create ns istio-system
kubectl apply -f ./mesh-config.yaml

cd istio-1.15.1
kubectl create ns foo
kubectl label namespace foo istio-injection=enabled --overwrite
kubectl apply -f samples/tcp-echo/tcp-echo.yaml -n foo
kubectl apply -f samples/sleep/sleep.yaml -n foo
kubectl apply -f samples/httpbin/httpbin.yaml -n foo


kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9000" | nc tcp-echo 9000' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'

kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9001" | nc tcp-echo 9001' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'


TCP_ECHO_IP=$(kubectl get pod "$(kubectl get pod -l app=tcp-echo -n foo -o jsonpath={.items..metadata.name})" -n foo -o jsonpath="{.status.podIP}")
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c "echo \"port 9002\" | nc $TCP_ECHO_IP 9002" | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'

kubectl create ns istio-ingress
./istio-1.15.1/bin/istioctl install -f ingress-gateway.yaml

kubectl get endpoints -n istio-ingress -o "custom-columns=NAME:.metadata.name,PODS:.subsets[*].addresses[*].targetRef.name"

export INGRESS_HOST=$(kubectl -n istio-ingress get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-ingress get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-ingress get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
export TCP_INGRESS_PORT=$(kubectl -n istio-ingress get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].port}')

export INGRESS_POD_NAME=$(kubectl get pods -n istio-ingress -o json | jq .items[0].metadata.name -r)

./istio-1.15.1/bin/istioctl proxy-config cluster -n istio-ingress $INGRESS_POD_NAME

export TCP_POD_NAME=$(kubectl get pods -n foo -o json | jq .items[0].metadata.name -r)

./istio-1.15.1/bin/istioctl proxy-config listeners -n foo $TCP_POD_NAME



echo "port 31400" | nc $INGRESS_HOST 31400 | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'

