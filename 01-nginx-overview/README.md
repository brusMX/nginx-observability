# Nginx logs and metrics overview

Because of the amount of [nginx container images](https://www.nginx.com/blog/wait-which-nginx-ingress-controller-kubernetes-am-i-using/) used in the wild, we will focus on the general concept of understanding nginx's metrics. If you want to know more about Nginx Plus, you should reach out to your Nginx plus contact they surely will have an answer and a full team to support you.

There are two main inputs that can be used to enable observability of your NGINX ingress controllers:

1. Nginx `stdout` and `stderr` logs.
2. Live nginx metrics `stub_status`.

Both of these inputs are based completely on the `nginx.conf` that your pod images have, by default in our nginx https ingress helm chart these are already enabled. In order to understand your ingress controllers on your cluster, you will need to understand that configuration file, or make sure that the image that your ingress controller is using has the configuration that fits your need.

## Verify your nginx configuration

Lets start by saying that the nginx configuration changes almost always, this can depend on the nginx version, the container publisher, or any other random weather change. This is why its important to verify that the log format and the metrics you need are consistent with the one you will be scraping.

There are three main categories our nginx pod can fit in when using Azure Kubernetes Service:

1. Nginx HTTPS ingress controller (recommended by docs).
2. AKS http add-on (not recommended for production).
3. Any other random nginx pod.

We will focus on the first one, since its the recommended way to create a proper production HTTPS ingress controller. This will mean that most of the code produced in this post is mainly directed to make it work on that case.

You can also make it work on the other cases, but you will probably have to manually update the nginx configuration to be consistent with the one used by the HTTPS ingress controller.

### Commands to verify your nginx configuration

1. Obtain all the nginx ingress pods deployed in your AKS cluster. *Note: this command assumes that your ingress controllers pods still have the string nginx-ingress as part of its name.

   ```bash
   kubectl get pods --all-namespaces | grep nginx-ingress
   ```

    In this case, I have multiple nginx pods running in different namespaces.

    ```bash
    kube-system    addon-http-application-routing-nginx-ingress-controller-8fsk87t   1/1     Running     0          4d13h
    kube-system    aks-ingress-nginx-ingress-controller-7bf454877d-cffdz             1/1     Running     0          4d13h
    kube-system    aks-ingress-nginx-ingress-controller-7bf454877d-md8mf             1/1     Running     0          4d13h
    kube-system    aks-ingress-nginx-ingress-default-backend-6c7d46c6f8-r48l7        1/1     Running     0          4d13h
    ```

    It's important to understand that metrics and logs can be obtained from all the nginx pods in the cluster but in this case, we will focus on the nginx https ingress controller since that would be our production ingress controlloer for our applications.

2. Verifying log format on `nginx.conf`. This next command will work if the label `"app=nginx-ingress"` is part of your ingress controllers pods, just as the https nginx ingress has it by default:

    ```bash
     kubectl exec -it $(kubectl get pods -l "app=nginx-ingress" -o jsonpath="{.items[0].metadata.name}") -- grep log_format nginx.conf
    ```

    You should probably get two lines, the first is  `upstreaminfo` that refers to the acces log and all the logging registered by nginx i.e. `stdout`.  And the second is `log_stream` that refers to the error logs i.e. `stderr`:

    ```bash
    log_format upstreaminfo '$the_real_ip - [$the_real_ip] - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_length $request_time [$proxy_upstream_name] $upstream_addr $upstream_response_length $upstream_response_time $upstream_status $req_id';

	log_format log_stream [$time_local] $protocol $status $bytes_sent $bytes_received $session_time;
    ```

    If the output you got is different than the one in this article, you will most likely have to adapt the regular expression in the fluentbit log parser to match your own.

3. Verifying that `stub_status` is `on`. It should be by default in most cases.
    ```bash
    kubectl exec -it $(kubectl get pods -l "app=nginx-ingress" -o jsonpath="{.items[0].metadata.name}") -- grep stub_status nginx.conf -B10 -A2
    ```

    ```bash
    	# this is required to avoid error if nginx is being monitored
		# with an external software (like sysdig)
            location /nginx_status {

                allow 127.0.0.1;

                deny all;

                access_log off;
                stub_status on;
            }

    --
                    ngx.say("OK")
                    ngx.exit(ngx.HTTP_OK)
                }
            }

            location /nginx_status {
                set $proxy_upstream_name "internal";

                access_log off;
                stub_status on;
            }
    ```
4. Make sure that the `stub_status` live metrics are working. *Note: In some OS this operation might require root access.

    ```bash
    export INGRESS_POD_NAME=$(kubectl get pods -l "app=nginx-ingress" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $INGRESS_POD_NAME 443
    ```
    And you should be able to visit <https://localhost:443/nginx_status>

    ```bash
    Forwarding from 127.0.0.1:443 -> 443
    Forwarding from [::1]:443 -> 443
    ```

    Where you will see the live metrics:

    ```Nginx
    Active connections: 4 
    server accepts handled requests
    266961 266961 177639 
    Reading: 0 Writing: 1 Waiting: 3 
    ```

5. Test that logs are being created. Connect to your ingress routes and verify that you can see the access log. If you don't remember the URL of your ingress controller, you can run the following command:

    ```bash
    kubectl get ingress --all-namespaces
    ```

    Now, run the following command to observe the logs and confirm you can see your foot print:

    ```bash
    kubectl logs -lapp=nginx-ingress --all-containers=true --tail 10 --all-namespaces
    ```

    ```Nginx
    10.244.0.1 - [10.244.0.1] - - [20/Feb/2019:00:30:55 +0000] "GET / HTTP/2.0" 200 359 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36" 449 0.013 [default-aks-helloworld-80] 10.244.2.52:80 629 0.016 200 666d716c4a53a55834641125cfd555f3
    ```

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

There are three main cases to be covered of NGINX services that can be scraped for metrics:

1) HTTPS Nginx Ingress controller - SSL terminated. This is the recommended standard ingress controller for production.
2) AKS HTTP Add on. No SSL. Used for dev and testing.
3) Bring your own Nginx image. This is not based on the ingress controller, instead you are in full control of deploying a container that has an Nginx instance running. These types of images cannot use the ingress annotations and must be manually configured.


## Enabling Stub Status

In order to obtain the desired metrics, we must enable the stub status in the nginx configuration. Usually in any Nginx service this would consists of the following steps:

1. Update `nginx.conf` to switch on `stub_status` in the server section of nginx:

    ```property
    server {
        listen   80;
        location /nginx_status {
            stub_status on;
        }
    }
    ```

2. Reload nginx configuration.
   
   ```bash
   nginx -s reload
   ```

Now, because this is happening in a kubernetes cluster these changes would not persist once a pod is killed. A couple of possible solutions could be a) create an nginx container image with the desired configuration or b) create a configmap and add it to the configuration folder

### Deploying nginx with metrics enabled

To test out the functionality of `stub_status` of Nginx, feel free to deploy the added `/artifacts` following these  commands:

1. Create a configmap with the needed nginx configuration.

    ```bash
    kubectl create configmap nginxconfig --from-file artifacts/default.conf
    ```

2. Create an instance of Nginx that uses this configmap and attaches it to `/etc/nginx/conf.d/default.conf` to replace the `server` configurations:

    ```bash
    kubectl create -f artifacts/nginxi-monitor.yaml
    ```
3. You will be able to ping the actual webserver through the external IP. This will take a few minutes:

    ```bash
    kubectl get svc -l name=nginx-monitor
    ---
    NAME            TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)        AGE
    nginx-monitor   LoadBalancer   10.0.0.217   104.211.31.99   80:30112/TCP   7m
    ```

4. The `/nginx_status` endpoint is not exposed to the internet, but we can forward the port to our localhost from one of the pods:


    ```bash
    export SERVER_POD=$(k get pods -l app=nginx-monitor -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $SERVER_POD 8080:8080
    ```
5. That's it, now proceed on your browser to <http://127.0.0.1/nginx_status> to see the metrics:

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
