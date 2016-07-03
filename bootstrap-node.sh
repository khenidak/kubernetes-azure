#!/bin/bash

# This script boot strap kubernetes cluster (nodes, not masters) by
# 1: download kubernetes bins
# 2: starts kubelet pointing to 10.0.0.4 (Azure internal load balancer infront of masters)
# 3: starts kube-proxy point to 10.0.0.4 as well
# 4: assigns a kubernetes label to current node = node group sequence 
# nodes are expected to follow an ip scheme 11.<node-group>.<node seq starting at 0>.4 (refer to readme.md file for more) 
# all configuration is done via systemd units.

# You can run this script via Azure custom script extentions on systemd + docker enabled hosts
  



#pre work
AZURE_USER=$1 #passed by the template


TARGET_LOG_FILE="/home/${AZURE_USER}/bootstrap.log"


exec >> "${TARGET_LOG_FILE}"
exec 2>&1


cd /home/${AZURE_USER}

THIS_NODE_NAME=$(hostname)  
THIS_NODE_IP=$(ifconfig eth0 | grep 'inet' | cut -d: -f2 | awk '{print $2}') 					
THREE_SEGS=$(echo ${THIS_NODE_IP} | awk -F "." '{printf "%s.%s.%s.", $1, $2, $3}') 
NODE_GROUPLABEL=$(echo ${THIS_NODE_IP} | awk -F "." '{printf "%s",  $2}')
CBR0_IP="${THREE_SEGS}128/25"



echo  "Resolved CBR IP as ${CBR0_IP}"




echo "+ downloading kubernetes"

#- Get Kubernetes 

wget https://github.com/kubernetes/kubernetes/releases/download/v1.2.4/kubernetes.tar.gz 
tar -xzvf  ./kubernetes.tar.gz 
tar -xzvf ./kubernetes/server/kubernetes-server-linux-amd64.tar.gz 

sudo mkdir -p /srv/kubernetes-server/bin
sudo cp -r ./kubernetes/server/bin/* /srv/kubernetes-server/bin/

echo "+ stop docker, then configure"



sudo systemctl stop docker.service

#Disable docker bridge and default iptables config
 sudo iptables -t nat -F
 sudo ifconfig docker0 down
 sudo brctl delbr docker0

 sudo brctl addbr cbr0 # create new bridge


sudo ip addr add ${CBR0_IP} dev cbr0 #give it ip within the same subnet as the node. 


# mkdir /etc/default/docker #todo check directory 
sudo touch /etc/default/docker
echo "DOCKER_OPTS=--bridge=cbr0 --iptables=false   --ip-masq=false" | sudo tee --append /etc/default/docker


# turn on masqarading for out going traffic 
sudo iptables -t nat -A POSTROUTING ! -d 10.0.0.0/8 -m addrtype ! --dst-type LOCAL -j MASQUERADE
sudo iptables -t nat -A POSTROUTING ! -d 11.0.0.0/8 -m addrtype ! --dst-type LOCAL -j MASQUERADE



# ** ** ** configure docker to work with modified flags.

sudo mkdir /etc/systemd/system/docker.service.d/
sudo touch /etc/systemd/system/docker.service.d/docker_opts.conf


echo "[Service]" | sudo tee --append /etc/systemd/system/docker.service.d/docker_opts.conf
echo "EnvironmentFile=-/etc/default/docker" | sudo tee --append /etc/systemd/system/docker.service.d/docker_opts.conf



sudo systemctl daemon-reload
sudo systemctl restart docker.service



echo "+ docker configured and started with the new options"


sudo touch /etc/systemd/system/kubelet.service


cat << EOL | sudo tee --append /etc/systemd/system/kubelet.service
[Unit]  
Description=Kubelet 
After=docker.service 
Requires=docker.service 

[Service] 

TimeoutStartSec=5 
ExecStart=/srv/kubernetes-server/bin/kubelet --api-servers=http://10.0.0.4:8080  

[Install] 
WantedBy=multi-user.target
EOL


# enable / start the service
sudo systemctl enable /etc/systemd/system/kubelet.service
sudo systemctl start kubelet.service

echo "+ started kubelet"



sudo touch /etc/systemd/system/kube-proxy.service


cat << EOL | sudo tee --append /etc/systemd/system/kube-proxy.service
[Unit]  
Description=Kube-proxy 
After=docker.service 
Requires=docker.service 

[Service] 

TimeoutStartSec=5 
ExecStart=/srv/kubernetes-server/bin/kube-proxy --master=http://10.0.0.4:8080

[Install] 
WantedBy=multi-user.target
EOL


# enable / start the service
sudo systemctl enable /etc/systemd/system/kube-proxy.service
sudo systemctl start kube-proxy.service

echo "+ started kubernetes proxy"


#add node group label to current node
cd /home/${AZURE_USER}/

sleep 30s # wait until node registers itself, note the node is active once registered
echo "Node Labeling: ${THIS_NODE_NAME}  with nodegoup=${NODE_GROUPLABEL}"
./kubernetes/cluster/kubectl.sh label nodes ${THIS_NODE_NAME} nodegoup=${NODE_GROUPLABEL} --server=http://10.0.0.4:8080

echo "+ Done!"