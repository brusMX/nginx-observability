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

1. Enable `stub_status`, easies way to do this is to create a configmap with the needed nginx configuration.

    ```bash
    kubectl create configmap nginxconfig --from-file artifacts/nginx.conf
    ```
2. 


## Sources

- https://sysdig.com/blog/monitor-nginx-kubernetes/