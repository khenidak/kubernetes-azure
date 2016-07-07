# Kubernetes on Azure
This repo contain Azure Resource Manager templates, scripts and tools that enables you to run Kubernetes on Azure.


# Motivation 

By all means this is not the only way you can run Kubernetes on Azure. However this one follows the following principles

1. Avoid additional platform dependencies, this deployment does not need network overlay such as Flannel, OVS or Weave traditionally needed by Kubernetes custom clusters refer to (http://kubernetes.io/docs/admin/networking/) for further details.

2. Delegate platform management (such as adding node, load balancers) to platform own interfaces (ARM templates, Azure CLI, REST in this case). This approach does not depend on Kubernetes Cloud Provider Model. The following are the reasons:
	- Kubernetes cloud provider is a common interface - highest common denominator - abstracting the underlying cloud resources. This means some of the features you may want in your cluster will not be available in the provider. And more importantly your architecture requirements might (likely will) be different than a common model (case in point internal vs external load balancers, or adding balancing rule vs add new load balancer, or adding Azure App Gateway vs Load Balancer). For further details on Kubernetes Cloud Model refer to (http://kubernetes.io/docs/getting-started-guides/#cloud)
	- Kubernetes Cloud Providers follows Kubernetes own release cycle. Recent cloud innovations is not going to be a part of what you can use - assuming that the provider maintainer is including them -  until you upgrade the entire cluster (or work some trickery around that). Because public clouds such as Azure are moving fast (and likely not slow down soon) it is safe assumption that new features will be always introduced. These features will either make your implementation better, faster or cheaper and you would want to roll them out to your cluster as fast as possible.

3. Create a cluster where you can easily compartmentalize groups of nodes by server type, specific subnet + routing rules or other factors.     



> The approach described below is designed to meet a complex set of requirements using the simplest possible approaches and  - familiar - tools yet it introduces an overhead. This overhead is acceptable in cases where you need to deploy complex and large clusters.  It is important to understand that if you have a single application running on a single - relatively small - Kubernetes cluster then you are probably better off using Cloud Provider Model. Check (https://github.com/colemickens/kubernetes) for effort on new Provider Model and (https://github.com/colemickens/azure-kubernetes-status) for overall Kubernetes + Azure status.  




# Deployment Overview

![Deployment Overview](/docs/img/deployment-overview.png)


The above diagram depicts how a Kubernetes cluster will work on Azure. The following notes explain the approach further:
- The deployment uses one Azure VNET with two address spaces 10.0.0.0/8 & 11.0.0.0/8
- Masters are deployed to their own subnet 10.0.0.0/24 running (on docker containers) etcd cluster, Kubernets Api Server, Kubernetes Controller Manager and scheduler behind an Azure internal load balancer (ILB) with fixed ip 10.0.0.4 and their own network security group (NSG).
- The deployment uses the following concept:
	- **Node Group** is a an Azure Availability Set (AvSet). Each has its own NSG. Each uses the following address approach 11.{node group index}.X.X
	- Each **Node** is a member of **Node Group** and is deployed to a 11.{node group index}.{node index}.0/24 subnet with fixed IP 11.[node group index}.{node index}.4 and fixed routing rule 11.{node group index}.{node index}.0/24 to 11.{node group index}.{node index}.4 this enables the cluster to work without any network overlays.
	- Each **Node** has a cbr0 bridge configured with 11.{node group index}.{node index}.128/25 IP carving 110 (out of node subnet) IPs for pods running on it.  
	- The entire set of node groups in one VNET is called node group set (a concept used only to scale beyond 400 nodes). 
- Each node runs Kube-Proxy & Kubelet and is labeled with nodegroup={node group index} (for pod constrained placement to node groups)
- The address space 10.1.0.0/16 is reserved for Kubernetes services and 10.1.255.255 is reserved for Kubernets DNS (no subnet created for this address space).
- Traffic can be ingested into the cluster via external load balancers, internal load balancers or reverse proxies such as nginx or Azure App Gateway.

## Compartmentalization ##
A center piece to this solution the ability to create compartments of nodes (node groups) Each can have the following characteristics:

1. Use its own H/W or OS (Linux distro)

2. Isolated by Azure NSG for network lockdown.

3. Can be exposed internally or externally via Internal or External Load Balancers. Or directly via public Azure VIP.

4. Use different Azure storage accounts. 

5. Each is an Azure Availability Set that has its own fault and upgrade domains.


## Node Groups Types (in Repo) ##
The following are node types included in the repo you can customize and/or create additional node group types as needed. 

1. Standard node groups, you can use these node groups for general purpose compute. 

2. Node Groups with ILB, a standard node group + an internal load balancers that can be used to face other systems connected to the same VNET. 

3. Node Groups with LB, a standard node group + external load balancers those can be used to ingest traffic from external sources (internet). 


> All the templates in this repo use CoreOs, the scripts contain notes on how to use a different distro. Each node group can run it is own Linux distro. 




## Capacity, Limits and Scale ##

Item | Max | Why | How to Increase
--- | --- | --- | ---
Masters | 250 | Subnet capacity | While you typically don't need more than 7 or 9 for large clusters. You can create additional masters in new 11.0.x.0/24 subnets. 
Nodes in Node Group | 255 | IPv4 addressing capacity (-1 for the 11.255.x.x group and -1 for ilb enabled node groups) | not supported
Node Groups in set (VNET) | 255 | IPv4 addressing capacity | Create new sets [refer to Deployment & Scale Guide](/docs/deployment-scale.md)
Total nodes in all groups in a node group set | 400 | Azure Routing Table limits | The capacity is actually default to 100 you can call support to increase 400 beyond that you will need to create additional node group set. 
Total Pods per Node| 110 | Node/Pod/Subnet/CBR0 configuration | not supported.

# Additional Information
1. Refer to [Deployment & Scale Guide] (/docs/deployment-scale.md) for 
	- How to deploy the solution?
	- How to deploy additional nodes?
	- How to deploy additional node groups
	- How to deploy additional node sets (scale beyond 400 nodes)? 
	- How to scale Masters?

3. Refer to [Traffic Ingestion] (/docs/traffic-ingestion.md) on how to ingest traffic into the cluster.
