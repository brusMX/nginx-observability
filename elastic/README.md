# Using the ELK stack for nginx observability

ELK is one of the most used stacks for observability. Let's install some of these components to understand our metrics.

## Non-production installation of ELK in AKS

If looking for a production installation of ELK, refer to [Azure/helm-elasticstack](https://github.com/Azure/helm-elasticstack).

1. Intall ElasticSearch

    ```bash
    helm install stable/elasticsearch \
    --name elasticsearch \
    --namespace logging
    --set data.persistence.storageClass=managed-premium,data.storage=20Gi
    ```

    This chart will create an elasticsearch service reachable inside of the cluster in the following URL:

    ```property
    elasticsearch-client.logging.svc
    ```

2. Install kibana. Use environment variables to select your installed elasticsearch service.

    ```bash
    helm install stable/kibana \
    --name kibana \
    --set env.ELASTICSEARCH_URL=http://elasticsearch-client.logging.svc:9200 \
    --namespace logging
    ```

## Using metricbeat for `stub_status`

- [Metricbeat k8s documentation](https://www.elastic.co/guide/en/beats/metricbeat/current/running-on-kubernetes.html)
- [Helm chart metricbeat](https://github.com/helm/charts/tree/master/stable/metricbeat)

Use the config file in `artifacts/metricbeat.yaml` ## TODO: make a configmap and import IPs from pods programmatically


Run the following command to identify your nginx ingress controller pods:

```bash
k get pods -o wide --all-namespaces | grep nginx
```

And you will get a table with all the current pods being used for the ingress controllers:

```bash
kube-system    aks-ingress-nginx-ingress-controller-7bf454877d-hmhss             1/1     Running     0          4d9h    10.244.0.46   aks-agentpool-31039371-0   <none>
kube-system    aks-ingress-nginx-ingress-controller-7bf454877d-n6w2g             1/1     Running     0          4d9h    10.244.0.48   aks-agentpool-31039371-0   <none>
kube-system    aks-ingress-nginx-ingress-default-backend-6c7d46c6f8-t9p4l        1/1     Running     0          4d9h    10.244.0.47   aks-agentpool-31039371-0   <none>
```

As you can see, there is one pod for the default backend and two for the ingress controller.
Both address should go into the list of nginx in the configuration file, look at this example:

```yaml
- module: nginx
  metricsets: ["stubstatus"]
  enabled: true
  period: 10s

  # Nginx hosts
  hosts: ["http://120.244.0.46:18080","http://120.244.0.48:18080"]

  # Path to server status. Default server-status
  server_status_path: "nginx_status"

```

The address goes with the port `18080` which is the default port where stub_status is enabled. Remember that each pod of the ingress controller needs to be captured to understand what request are being processed by each pod.
Now that the yaml file has being configured, deploy the helm chart with your new `values.yaml` file:

```bash
helm install --name metricbeat -f artifacts/metricbeat/values.yaml --namespace logging stable/metricbeat 
```

The url

Install helm chart 