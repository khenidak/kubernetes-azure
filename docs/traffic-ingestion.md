# Traffic Ingestion #
The following are supported models to ingest traffic into the cluster

## Via Load Balancers ##
You can use internal load balancers or external load balancers to ingest traffic into the cluster. The model works as the following:

1. Create or use existing node group (that has ilb/ or lb).
2. Optional: pods that needs to be exposed externally can be anchored to this group type.
3. Services exposed exposed externally are created with *type: NodePort* + fixed node ports in Kubernetes 30000-32767 range. There is no need to use privileged ports.
4. Load Balancing rules must be created to route external traffic to these ports.     

> 
Refer to [Deployment & Scale Guide](/docs/deployment-scale.md) on how to create node groups
Refer to /ingest-via-loadbalancer/ for sample replication controller and service. 

## Via Azure App Gateway As a Reverse Proxy + Load Balancer##

> In this model you don't need a load balancer because App Gateway is L7 Load Balancer.

1. Create Azure App Gateway in your VNET.
2. Create your replication controller and services following step 2 and 3 above.
3. Configure App Gateway to route traffic as needed (App Gateway will use nodes ips).  


## Via Custom Reverse Proxies Such As Nginx ##

### Option 1: Manually ###
You can deploy pods that contain Nginx image (optionally with a small etcd - or Zoo Keeper - cluster for shared config) in addition to load balancer as described above.


### Option 2: Via Ingress Controller ###  
Refer to [Nginx Kubernetes Ingress Controller](https://www.nginx.com/blog/load-balancing-kubernetes-services-nginx-plus/) for details, the samples are hosted [here](https://github.com/nginxinc/kubernetes-ingress/tree/master/examples/complete-example)

