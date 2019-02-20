# AKS - Observability on your NGINX ingress controllers

The main goal of this document is to provide developer the tools to understand better their Web services running on Kubernetes. Because of the popularity of Web Services, the first attempt of this document concentrates on services running on HTTP/HTTPS. Mainly because (in my opinion) I have observed that our partners and customers, want to always improve the quality of service they offer to their customers. Because Web Services or API's tend to be the last mile to the customer, this is a great place to start.

The reason why I concentrate on NGINX instead of other ingress controllers, its because of its popularity. Also, because some other ingress controllers offer out of the box dashboards and analytics and they can become easier to monitor. Later on, I would like to continue this work by including other popular ingress controllers like traefik and HAproxy.

## TL;DR

These are the steps to be followed in order to start monitoring your Nginx Ingress controllers:

1. [Create an HTTPS ingress controller on AKS.](https://docs.microsoft.com/en-us/azure/aks/ingress-tls)
2. Understand and verify the log format that NGINX uses.
3. Create a FluentBit DaemonSet that scrapes your current logs and pushes them to Azure Log Analytics
4. Create custom queries and dashboards to fully understand your business.
5. Create alerts and actionables to ensure your Site Reliability



## Sources

- [Stub Status Nginx module](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html)
- [Access Stub Status from Nginx Ingress controller](https://github.com/nginxinc/kubernetes-ingress/blob/master/docs/installation.md#5-access-the-live-activity-monitoring-dashboard--stub_status-page)
- [Sysdig monitoring Nginx on k8s](https://sysdig.com/blog/monitor-nginx-kubernetes/)
- [Datadog monitoring Nginx on k8s](https://www.datadoghq.com/blog/how-to-collect-nginx-metrics/)
- [How to monitor NGINX](https://github.com/DataDog/the-monitor/blob/master/nginx/how_to_monitor_nginx.md)
- [StackOverflow: Analize nginx logs](https://stackoverflow.com/questions/12589003/simple-nginx-log-file-analyzer)
- <https://danielfm.me/posts/painless-nginx-ingress.html>