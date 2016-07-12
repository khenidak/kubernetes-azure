# Deployment & Scale Guide 

## Deploy the Solution ##

### 1. Deploy Core Resources ###
1. Deploy the main.json ARM template to your Azure Resource Group. This will create masters, node groups and nodes. 
2. Modify then run configure-cluster.sh on your local machine (Modify the first section of the script that includes the parameters. *You will need to do that everytime you add a node or a node group).

> The configuration script ssh into masters for configuration, then ssh into master-0 to configure nodes un-comment the last line to remove the ssh keys from master-0 


### 2. Deploy Kubernetes UI ###
 1. Deploy /kubernetes-ui/kubernetes-dashboard-service.yaml via *kubctl.sh create -f ...*
 2. Deploy /kubernetes-ui/kubernetes-dashboard-deployment.yaml via *kubctl.sh create -f ...*
 
> The above creates kubernetes ui component on http://10.0.0.4:8080/ui. Tip: tunnel into one of the Masters using ssh <cluster dns label>:500X -L 9000:10.0.0.4:8080 and use your local machine browser to access the UI and run kubectl.sh localy. 


### 3. Deploy Kubernetes DNS ###
1. Deploy /kubernetes-dns/kubernetes-dns-rc.yaml 
2. Deploy /kubernetes-dns/kubernetes-dns-svc.yaml

This will create your dns service listening on 10.1.255.255:53 (use [selector or node affinity](http://kubernetes.io/docs/user-guide/node-selection/)  if you want to anchor the DNS service to specific node group). The default cluster domain used cluster.local You can modify accordingly.


## 4. Add New Node Group to Existing Cluster ##
1. General Purpose Compute Node Groups 
	- create-node-group.json with parameters.create-node-group.json (sample only you have to modify) 
2. Node Groups with ILB
	- create-node-group-ilb.json with parameters.create-node-group-ilb.json (sample only you have to modify) 
> The ilb will be deployed with IP = 11.<node group index>.255.4
3. Node Group with LB
	- create-node-group-lb.json with parameters.create-node-group-lb.json (sample only you have to modify) 
 
> In all cases after ARM deployment adjust configure-cluster.sh and re-run it on your local machine.

note: you can modify NSG as needed to accommodate specific network lock down requirements.  

## Add New Node in Existing Node Group ##

1. Depending on your need you can use create-node.json (or modify it to include it in an existing lb or ilb). 
2. Modify configure-cluster (first section, the parameters section) then run it on your local machine.


## Create New Node Group Type ##
For Example: to accommodate specific VM H/W type, OS type or using different storage accounts/storage account types for this node group. 

1. Create a copy of one of the create-node-group-*.json files. 
2. Modify the template as needed. 
3. Deploy the template to your ARM resource group.
4. Modify and run configure-cluster.sh

> if you need different node bootstrap steps then create a copy of node-bootstrap.sh and modify it accordingly. 


# Add New Node Group Set (scale beyond 400 nodes) #
![Multiple Node Sets](/docs/img/multiple-node-sets.png)

1. Create a new VNET with at least one address space that is not 11.0.0.0/8 for example choose 12.0.0.0/8.
2. Ensure that the masters ilb at 10.0.0.4 is route-able to, from the new VNET.
3. Modify create-node-group*.json files and deploy accordingly.
4. Modify configure-cluster.sh and re-run them to bootstarp the new nodes.

> The bootstrap-node.sh script labels the nodes according to group index. you may want to consider different label scheme for the new node set.    

# Scaling Masters#

## Scale up Masters ##
In this solution masters perform considerable disk i/o (for etcd which currently uses raft algorithm). Consider the following:

1. Use Azure Premium Storage (SSD Backed) for master. 
2. Consider adding additional disks to masters for etcd specific data (those can be SSD backed).refer to [etcd Admin Guide](https://coreos.com/etcd/docs/latest/admin_guide.html) for more info on changing wal and data directory location.   

> the solution by default creates different storage accounts for masters (mapped 1:1)

## Scale out Masters ## 
You can manually add masters to master VM AvSet then configure it. follow [etcd Runtime Re-Configuration](https://coreos.com/etcd/docs/latest/runtime-configuration.html) to learn more.

