# Using fluentbit to capture your Nginx metrics

Fluentbit is lightweight open source amazing LogProcessor and Forwarder. We will use it to scrape and collect the metrics of our Nginx Ingress controllers.

## Installing fluentbit in K8s cluster

Simply enough, the installation consists on creating a new namespace, create the needed services account and roles,  deploy the DaemonSet to your cluster. For more information, visit fluentbit's [documentation website](https://docs.fluentbit.io/manual/installation/kubernetes#installation).

This fluentbit installation will by default output all kubernetes logging to elastic search.



### Steps for installation

This steps will get fluentbit injecting logs into Elasticsearch. Make sure you have followed the steps to [deploy Elasticsearch and kibana on AKS](../elastic)

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

## Processing the Logs

Let's analyze fluent bit configmap.

Input retrieves all the logs from the containers which name matches `*nginx*controller`:

```yaml
input-nginx.conf: |
[INPUT]
    Name              tail
    Tag               nginx.*
    Path              /var/log/containers/*nginx*controller*.log
    DB                /var/log/flb_kube_nginx.db
    Mem_Buf_Limit     10MB
    Refresh_Interval  10 
```

To the input we apply the first filter, a custom Docker parser. This docker parser pulls the logs inside the docker format and decodes the escaped strings, things like `\" or \n` are decoded. This is needed for our next filter which consistes in regular expressions that need the strings to be clean.

```yaml
filter-docker.conf: |
[FILTER]
    Name                parser
    Match               nginx.*.log
    Key_Name            log
    Parser              docker

---

[PARSER]
    Name         docker
    Format       json
    Time_Key     time
    Time_Format  %Y-%m-%dT%H:%M:%S.%L
    Time_Keep    On
    # Command      |  Decoder | Field | Optional Action
    # =============|==================|=================
    Decode_Field_As   escaped       log
```

The final step is the nginx filter. Let's take a look at the produced log after the docker filter:

```json
[135] 
nginx.var.log.containers.aks-ingress-nginx-ingress-controller-7bf454877d-cffdz_kube-system_nginx-ingress-controller-764d722d41ee3a7c7cf1f9ba13c6e0694481f36a0bd125bc526030521f2da486.log:
 [1550253878.582906897, 
    {
        "log"       =>  
            "10.244.2.1 - [10.244.2.1] - - [15/Feb/2019:18:04:38 +0000] "GET /static/acs.png HTTP/1.1" 200 2636 "-" "Mozilla/5.0 (apple-x86_64-darwin18.2.0) Siege/4.0.4" 211 0.000 [default-aks-helloworld-80] 10.244.2.52:80 2636 0.000 200 d4c2a9f907a8c06b9be1ae10fcbb8730",
        "stream"    =>
            "stdout",
        "time"      =>
            "2019-02-15T18:04:38.578102375Z"}]
```

According to the documentation the best way to test the regular expressions is using the website [rubular](https://rubular.com/r/qucBORIMGOUgIM)

```yaml
[PARSER]
    Name        nginx
    Format      regex
    Regex       ^(?<originip>[^ ]*) - \[(?<roriginip>[^ ]*)\] - (?<remoteuser>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?)(?: +\S*)?)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)") (?<requestlenght>[^ ]*) (?<requesttime>[^ ]*) \[(?<proxy>[^ ]*)\] (?<upstreamaddress>[^ ]*):*(?<upstreamport>[^ ]*) (?<upstreamresponselength>[^ ]*) (?<upstreamresponsetime>[^ ]*) (?<upstreamstatus>[^ ]*) (?<requestid>[^ ]*)$
    Time_Key    time
    Time_Format %d/%b/%Y:%H:%M:%S %z
```

## Injecting the metrics

For fluentbit, the only thing you must add is an output.
For Azure Monitor there is already an Output that can be used to send them. You must only obtain you workspace ID and your key.

```yaml
[OUTPUT]
        Name azure
        Match       *
        Customer_ID  << WORKSPACE ID>>
        Shared_Key  << SHARED KEY >>
```

## Querying LogAnalytics

By default you will see the metrics under the name `fluentbit_CL`. Now lets play with the queries to obtain useful results.

1. All fluentbit metrics obtained in the last hour:
2. 
    ```sql
    fluentbit_CL  | 
    where TimeGenerated  > ago(1h)
    ```

3. List all the ingress controllers

   ```sql
   KubeServices
    | where ServiceName contains "ingress"
    | where ServiceName !contains "backend"
    | distinct ServiceName
    ```




4. Requests per second
5. 


