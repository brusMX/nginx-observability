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

To test out the functionality of stub_status of nginx, feel free to deploy the added artifacts following the next commands:

1. Create a configmap with the needed nginx configuration.

    ```bash
    kubectl create configmap nginxconfig --from-file artifacts/default.conf
    ```

1. Create an instance of Nginx that uses this configmap and attaches it to `/etc/nginx/conf.d/default.conf` to replace the `server` configurations:

    ```bash
    kubectl create -f artifacts/nginxi-monitor.yaml
    ```
1. Wait until the service is up and running and the following command returns an actual external IP:

    ```bash
    kubectl get svc -l name=nginx-monitor
    ---
    NAME            TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)        AGE
    nginx-monitor   LoadBalancer   10.0.0.217   104.211.31.99   80:30112/TCP   7m
    ```

1. That's it, now proceed to the new ip, followed by the route where we are posting the metrics `/nginx_status` and you will see the metrics:

    ```text
    Active connections: 3
    server accepts handled requests
    12779 12779 484
    Reading: 0 Writing: 1 Waiting: 2
    ```

## Activate metrics on a pre-provisioned Nginx server

First, let's remember that by default `stub_status` is 
Let's start by provisioning an Nginx server and then we will update it's nginx configuration to expose the needed metrics on the route /nginx_status.

### Provision an out-of-the-box Nginx server

1. Deploy nginx on your server

    ```bash
    kubectl run server --image=nginx
    ```

1. Expose it to the internet:

    ```bash
    kubectl expose deployment server --type=LoadBalancer --port=80
    ```
1. Wait for the external IP of the LoadBalancer to come back, and confirm that your server is up and running by going to that IP from your browser:

    ```bash
    kubectl get svc -l name=server
    ---
    NAME    TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)        AGE
    server  LoadBalancer   10.0.0.217   104.21.31.101   80:30112/TCP   7m
    ```

1. Check that the service is up and running by going ot the external ip through your browser and verify that NGINX is up and running.

### Add stub status to a pre provisioned nginx

1. Create a configmap and replace the original `default.conf` file from the current Nginx instance. Note: This will override any custom Nginx server configuration that your server might have. If you haven't done so, create the configmap from our artifacts
2. Export the Deployment to a temporary file.

   ```bash
    kubectl get -o yaml --export deployment.apps server > pre-server.yaml
    ```

3. Add the configmap volume to the yaml file.

   ```yml
        volumeMounts:
        - name: "config"
          mountPath: "/etc/nginx/conf.d/default.conf"
          subPath: default.conf
      volumes:
        - name: "config"
          configMap:
            name: "nginxconfig"
    ```

    Make sure that `volumeMonts` is at the indentation level of `image` and that `volumes` is at the indentation level of containers. Both of them should be inside of `Deployment.spec.template.spec`. Here is an example: 

    ```yml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
    annotations:
        deployment.kubernetes.io/revision: "1"
    creationTimestamp: null
    generation: 1
    labels:
        run: server
    name: server
    selfLink: /apis/apps/v1/namespaces/default/deployments/server
    spec:
    progressDeadlineSeconds: 600
    replicas: 1
    revisionHistoryLimit: 10
    selector:
        matchLabels:
        run: server
    strategy:
        rollingUpdate:
        maxSurge: 1
        maxUnavailable: 1
        type: RollingUpdate
    template:
        metadata:
        creationTimestamp: null
        labels:
            run: server
        spec:
        containers:
        - image: nginx
            imagePullPolicy: Always
            name: server
            resources: {}
            terminationMessagePath: /dev/termination-log
            terminationMessagePolicy: File
            volumeMounts:
            - name: "config"
            mountPath: "/etc/nginx/conf.d/default.conf"
            subPath: default.conf
        volumes:
            - name: "config"
            configMap:
                name: "nginxconfig"
        dnsPolicy: ClusterFirst
        restartPolicy: Always
        schedulerName: default-scheduler
        securityContext: {}
        terminationGracePeriodSeconds: 30
    status: {}
    ```
4. Apply the changes and let the rolling update kick in (if deployment configuration is the default one)

   ```bash
    kubectl apply -f pre-server.yaml
    ```

5. On your browser go to the external ip followed by the `/nginx_status` route

## Sources

- [Stub Status Nginx module](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html)
- [Access Stub Status from Nginx Ingress controller](https://github.com/nginxinc/kubernetes-ingress/blob/master/docs/installation.md#5-access-the-live-activity-monitoring-dashboard--stub_status-page)
- [Sysdig monitoring Nginx on k8s](https://sysdig.com/blog/monitor-nginx-kubernetes/)
- [Datadog monitoring Nginx on k8s](https://www.datadoghq.com/blog/how-to-collect-nginx-metrics/)
