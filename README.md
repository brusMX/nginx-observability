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

## Getting started with the Stub Status

- AKS cluster
- Kubectl binary connected to your cluster

To test out the functionality of `stub_status` of Nginx, feel free to deploy the added artifacts following the next commands:

1. Create a configmap with the needed nginx configuration.

    ```bash
    kubectl create configmap nginxconfig --from-file artifacts/default.conf
    ```

1. Create an instance of Nginx that uses this configmap and attaches it to `/etc/nginx/conf.d/default.conf` to replace the `server` configurations:

    ```bash
    kubectl create -f artifacts/nginxi-monitor.yaml
    ```
1. You will be able to ping the actual webserver through the external IP. This will take a few minutes:

    ```bash
    kubectl get svc -l name=nginx-monitor
    ---
    NAME            TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)        AGE
    nginx-monitor   LoadBalancer   10.0.0.217   104.211.31.99   80:30112/TCP   7m
    ```

1. The `/stub_status` endpoint is not exposed, but we can forward the port to our localhost from one of the pods:


    ```bash
    export SERVER_POD=$(k get pods -l app=nginx-monitor -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $SERVER_POD 8080:8080
    ```
1. That's it, now proceed on your browser to <http://127.0.0.1:8080/stub_status> to see the metrics:

    ```text
    Active connections: 3
    server accepts handled requests
    12779 12779 484
    Reading: 0 Writing: 1 Waiting: 2
    ```

## Activate metrics on a pre-provisioned Nginx server

First, let's remember that by default `stub_status` is 
Let's start by provisioning an Nginx server and then we will update it's nginx configuration to expose the needed metrics on the route /stub_status.

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

    ...
        volumeMounts:
        - name: "config"
          mountPath: "/etc/nginx/conf.d/monitor.conf"
          subPath: monitor.conf
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

5. Obtain one of the pods name that has been updated and on your browser go to <http://127.0.0.1:8080/stub_status>  to see the metrics.

## Understanding nginx logs

The second part that we need to understand is where are the logs located on the Nginx server container.

1. Get the logs of one of the containers of the service:

    ```bash
    kubectl logs << POD NAME >>
    ---
    2019/01/16 22:48:22 [error] 6#6: *2 "/etc/nginx/html/index.html" is not found (2: No such file or directory), client: 127.0.0.1, server: localhost, request: "GET / HTTP/1.1", host: "127.0.0.1:8080"
    127.0.0.1 - - [16/Jan/2019:22:48:22 +0000] "GET / HTTP/1.1" 404 555 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36" "-"
    2019/01/16 22:48:22 [error] 6#6: *2 open() "/etc/nginx/html/favicon.ico" failed (2: No such file or directory), client: 127.0.0.1, server: localhost, request: "GET /favicon.ico HTTP/1.1", host: "127.0.0.1:8080", referrer: "http://127.0.0.1:8080/"
    127.0.0.1 - - [16/Jan/2019:22:48:22 +0000] "GET /favicon.ico HTTP/1.1" 404 555 "http://127.0.0.1:8080/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36" "-"
    127.0.0.1 - - [16/Jan/2019:22:49:14 +0000] "GET / HTTP/1.1" 200 612 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36" "-"
    ```

    As you can see the structure of the logs is variable because it includes both stdout and stderr.

    Here is how stdout should look like if it's left by default (read from my nginx created container) :

    ```bash
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    ```

    Or in other words:
    ```bash
    NGINXACCESS %{IPORHOST:clientip} - %{USERNAME:remote_user} \[%{HTTPDATE:time_local}\] %{QS:request} %{INT:status} %{INT:body_bytes_sent} %{QS:http_referer} %{QS:http_user_agent}
    ```

    And for default errors:
    
    ```bash
     NGINXERROR (?<timestamp>%{YEAR}[./-]%{MONTHNUM}[./-]%{MONTHDAY}[- ]%{TIME}) \[%{LOGLEVEL:severity}\] %{POSINT:pid}#%{NUMBER}: %{GREEDYDATA:errormessage}(?:, client: (?<clientip>%{IP}|%{HOSTNAME}))(?:, server: %{IPORHOST:server})(?:, request: %{QS:request})?(?:, host: %{QS:host})?(?:, referrer: \"%{URI:referrer})?
    ```

1. Build an Azure Log Analytics query for stdout, here is an example, you can change the Start 

    ```sql
    // Variable to your container
    let startDateTime = datetime('2019-01-17T11:45:00.000Z');
    let endDateTime = datetime('2019-01-17T17:59:07.172Z');
    let myContainer = 'feb2fd3c-19de-11e9-b922-ee7e129f2c8a/server';
    let myCluster ="aks-svc-obs";
    let whichLog = "stdout";
    // Query
    let ContainerIdList = KubePodInventory
    | where TimeGenerated >= startDateTime and TimeGenerated < endDateTime
    | where ContainerName =~ myContainer
    | where ClusterName =~ myCluster
    | distinct ContainerID;
    ContainerLog
    | where TimeGenerated >= startDateTime and TimeGenerated < endDateTime
    | where ContainerID in (ContainerIdList)
    | where LogEntrySource contains whichLog 
    | parse LogEntry with RemoteAddr "-" RemoteUser "- [" TimeLocal "] \"" ReqType " " Url " " Protocol "\"" ReqStatus " " BodyBytesSent " \"" HttpReferer  "\" \"" UserAgent "\" \"" ForwardedFor "\"" *
    | project  LogEntrySource, RemoteAddr, RemoteUser, TimeLocal, ReqType, Url,  Protocol, ReqStatus, BodyBytesSent, HttpReferer, UserAgent, ForwardedFor, TimeGenerated, Computer, Image, Name, ContainerID, LogEntry
    | order by TimeGenerated desc
    | project-away LogEntry
    | render table;
    ```

1. Build an Azure Log Analytics query for stderr, here is an example:

    ```sql
    // Variable to your container
    let startDateTime = datetime('2019-01-17T11:45:00.000Z');
    let endDateTime = datetime('2019-01-17T17:59:07.172Z');
    let myContainer = 'feb2fd3c-19de-11e9-b922-ee7e129f2c8a/server';
    let myCluster ="aks-svc-obs";
    let whichLog = "stderr";
    // Query
    let ContainerIdList = KubePodInventory
    | where TimeGenerated >= startDateTime and TimeGenerated < endDateTime
    | where ContainerName =~ myContainer
    | where ClusterName =~ myCluster
    | distinct ContainerID;
    ContainerLog
    | where TimeGenerated >= startDateTime and TimeGenerated < endDateTime
    | where ContainerID in (ContainerIdList)
    | where LogEntrySource contains whichLog 
    | parse LogEntry with DateTimeLocal "[" Severity "]" PID "#" TID ": *" CID " "  ErrorMessage 
    | project  LogEntrySource, DateTimeLocal, Severity, PID, TID, CID, ErrorMessage, TimeGenerated, Computer, Image, Name, ContainerID, LogEntry
    | order by TimeGenerated desc
    | project-away LogEntrySource,  TimeGenerated, Computer, Image, Name, ContainerID
    | render table;
    ```

## Sources

- [Stub Status Nginx module](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html)
- [Access Stub Status from Nginx Ingress controller](https://github.com/nginxinc/kubernetes-ingress/blob/master/docs/installation.md#5-access-the-live-activity-monitoring-dashboard--stub_status-page)
- [Sysdig monitoring Nginx on k8s](https://sysdig.com/blog/monitor-nginx-kubernetes/)
- [Datadog monitoring Nginx on k8s](https://www.datadoghq.com/blog/how-to-collect-nginx-metrics/)
- [How to monitor NGINX](https://github.com/DataDog/the-monitor/blob/master/nginx/how_to_monitor_nginx.md)
- [StackOverflow: Analize nginx logs](https://stackoverflow.com/questions/12589003/simple-nginx-log-file-analyzer)
