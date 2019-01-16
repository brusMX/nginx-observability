# AKS: How to enable observability on your NGINX services

This document will explain the needed parts to monitor your services running through NGINX on Azure Kubernetes Service.
We'll leverage "stub_status" on Nginx to obtain the following metrics:

- Nginx connections:
  - Service availability
  - Number of active connections
  - New connections per second
  - Dropped connections per second
- Nginx requests status:
  - Request per second.
  - Reading, waiting, writing
- Nginx HTTP Application metrics:
  - Request count per URL
  - Request time for URL
  - HTTP response code 

All these metrics are obtained per pod, this means that tagging is an essential element to segmenting information of these requests.


## Getting started

- AKS cluster
- Kubectl binary connected to your cluster

1. Start by creating an NGINX instance:

    ```bash
    kubectl run server --image=nginx
    ```

1. Expose it to the internet:

    ```bash
    kubectl expose deployment server --type=LoadBalancer --port=80
    ```

1. Wait for the external IP of the LoadBalancer to come back, and confirm that your server is up and running by going to that IP from your browser:

    ```bash
    kubectl get svc
    ```

1. Create a configmap with the needed nginx configuration.

    ```bash
    kubectl create configmap nginxconfig --from-file artifacts/nginx.conf
    ```
2. Check the status going to the IP plus the route /nginx_status


## Sources

- [<https://sysdig.com/blog/monitor-nginx-kubernetes/>]
- [<https://www.datadoghq.com/blog/how-to-collect-nginx-metrics/]>