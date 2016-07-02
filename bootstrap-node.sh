#!/bin/bash

#pre work
AZURE_USER=$1 #passed by the template


TARGET_LOG_FILE="/home/${AZURE_USER}/bootstrap.log"


exec >> "${TARGET_LOG_FILE}"
exec 2>&1


cd /home/${AZURE_USER}


THIS_NODE_IP=$(ifconfig eth0 | grep 'inet' | cut -d: -f2 | awk '{print $2}') 					
THREE_SEGS=$(echo ${THIS_NODE_IP} | awk -F "." '{printf "%s.%s.%s.", $1, $2, $3}') 
CBR0_IP="${THREE_SEGS}1/24"



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


#TODO: Add symbolic link 
#TODO: Add node group as a node label on the current node


echo "+ Done!"