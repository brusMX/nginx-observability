# Using fluentbit to capture your Nginx metrics

Fluentbit is lightweight open source amazing LogProcessor and Forwarder. We will use it to scrape and collect the metrics of our Nginx Ingress controllers.

## Installing fluentbit in K8s cluster

Simply enough, the installation consists on creating a new namespace, create the needed services account and roles,  deploy the DaemonSet to your cluster. For more information, visit fluentbit's [documentation website](https://docs.fluentbit.io/manual/installation/kubernetes#installation).

This fluentbit installation will by default output all kubernetes logging to elastic search.

### Non-production installation of ELK in AKS

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


### Steps for installation

This steps will get fluentbit injecting logs into Elasticsearch.

1. Create ns, sa, and, roles:

   ```bash
   kubectl create namespace logging
   kubectl create -f https://raw.githubusercontent.com/fluent/fluent-bit-kubernetes-logging/master/fluent-bit-service-account.yaml
   kubectl create -f https://raw.githubusercontent.com/fluent/fluent-bit-kubernetes-logging/master/fluent-bit-role.yaml
   kubectl create -f https://raw.githubusercontent.com/fluent/fluent-bit-kubernetes-logging/master/fluent-bit-role-binding.yaml
   ```

2. Instead of using the default config file, use the one in this repository `artifacts/fluent-bit-configmap-nginx.yaml`:

    ```bash
    kubectl apply -f artifacts/fluent-bit-configmap-nginx.yaml
    ```

3. Deploy the DS with your configmap. Make sure to update the URL of the elasticsearch service.

    ```bash
    kubectl create -f artifacts/fluent-bit-ds.yaml
    ```

## Scraping the Logs

## Pinging the  nginx status

## Processing the information

## Injecting the metrics
