#!/bin/bash 

#pre work
AZURE_USER=$1 #passed by the template


TARGET_LOG_FILE="/home/${AZURE_USER}/bootstrap.log"
mkdir "/home/${AZURE_USER}/etd-data/"

exec >> "${TARGET_LOG_FILE}"
exec 2>&1

echo "++++++++ Kuberenetes Bootstrap starting at $(date) +++++++++++++++"



#Constants 
CLUSTER_MASTER_IP="10.0.0.4" #internal load balancer Ip



#Vars
LOCAL_ETCD_NAME=$(hostname)  
LOCAL_ETCD_IP=$(ifconfig eth0 | grep 'inet' | cut -d: -f2 | awk '{print $2}') 					
INIT_CLUSTER_RING="${LOCAL_ETCD_NAME}=http://${LOCAL_ETCD_IP}:2380," # all other hosts will be concat-ed to this
CLUSTER_ETCD_SERVERS="http://${LOCAL_ETCD_IP}:2379," #all other etcd servers will concated here 
INIT_CLUSTER_TOKEN="azure-kubernetes-cluster"
MAX_SEQ=10 # number of connected vm to masters sub net (after taking out azure reserved ip and the internal load balancer)
BASE_SERVERS_NAME='master'
LOCAL_SERVER_SEQUENCE=$(hostname | awk -F "-" '{print $2}') 

echo "Current server host ${LOCAL_ETCD_NAME} with ip ${LOCAL_ETCD_IP} with sequence ${LOCAL_SERVER_SEQUENCE}"
echo "Identified base host name as ${BASE_SERVERS_NAME}"

SEQ=0


# get etcd cluster ring servers. 

while [ $SEQ -lt $MAX_SEQ ]
do
  
   FOUND_HOST="${BASE_SERVERS_NAME}-${SEQ}"
   
   if [ "$FOUND_HOST" == "$LOCAL_ETCD_NAME" ]
   then

	echo "Found host: $FOUND_HOST and is equal to current etcd- ignoring" 
   
   else
	
	if [ "`ping -c 1 ${FOUND_HOST}`" ]
	then
	    FOUND_HOST_IP="`host ${FOUND_HOST} | awk '/has address/ { print $4 }'`"
		echo "Found Host: ${FOUND_HOST} and is alive, adding"
		INIT_CLUSTER_RING="${INIT_CLUSTER_RING}${FOUND_HOST}=http://${FOUND_HOST_IP}:2380,"
        CLUSTER_ETCD_SERVERS="${CLUSTER_ETCD_SERVERS}http://${FOUND_HOST_IP}:2379,"

	else
		echo "Found Host: ${FOUND_HOST} and is NOT alive, WILL NOT add"
	fi

   fi
   SEQ=`expr $SEQ + 1`
done

INIT_CLUSTER_RING=${INIT_CLUSTER_RING:0:(-1)}
CLUSTER_ETCD_SERVERS=${CLUSTER_ETCD_SERVERS:0:(-1)} #etcd servers without xxx=http://yyy:2379 used by the kub api server api server

echo "+ config auto- start etcd on Docker with ring   ${INIT_CLUSTER_RING} @ $(date)"




sudo touch /etc/systemd/system/etcd-container.service


cat << EOL | sudo tee --append /etc/systemd/system/etcd-container.service
[Unit]  
Description=etcd-container
After=docker.service 
Requires=docker.service 

[Service] 

TimeoutStartSec=10 
ExecStartPre=-/usr/bin/docker kill etcd
ExecStartPre=-/usr/bin/docker rm etcd
ExecStart=/usr/bin/docker run -d -v /usr/share/ca-certificates/:/etc/ssl/certs  -v /home/${AZURE_USER}/etd-data:/etc/etcd-data/ -p 4001:4001 -p 2380:2380 -p 2379:2379 \
 		--hostname=${LOCAL_ETCD_NAME} \
		--name etcd quay.io/coreos/etcd:v2.2.1 \
		--name "${LOCAL_ETCD_NAME}" \
 		--advertise-client-urls http://${LOCAL_ETCD_IP}:2379,http://${LOCAL_ETCD_IP}:4001 \
 		--listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
 		--initial-advertise-peer-urls http://${LOCAL_ETCD_IP}:2380 \
 		--listen-peer-urls http://0.0.0.0:2380 \
 		--initial-cluster-token ${INIT_CLUSTER_TOKEN} \
 		--initial-cluster ${INIT_CLUSTER_RING} \
 		--initial-cluster-state new \
		-data-dir /etc/etcd-data/
		

[Install] 
WantedBy=multi-user.target
EOL




# enable / start the service
sudo systemctl enable /etc/systemd/system/etcd-container.service
sudo systemctl start etcd-container.service


echo "+ Sleeping 10 sec for etcd cluster to become healthy"

sleep 10s 

echo "+ Starting Kubernetes API Server (Docker)"



sudo touch /etc/systemd/system/kubernetesApiServer-container.service


cat << EOL | sudo tee --append /etc/systemd/system/kubernetesApiServer-container.service
[Unit]  
Description=Kubernetes-Api-Server
After=docker.service 
Requires=docker.service 

[Service] 

TimeoutStartSec=5 
ExecStartPre=-/usr/bin/docker kill apiserver
ExecStartPre=-/usr/bin/docker rm apiserver
ExecStart=/usr/bin/docker run -d -p 8080:8080 \
				--net=host \
				--name apiserver gcr.io/google_containers/hyperkube:v1.2.4 \
				/hyperkube apiserver \
				--service-cluster-ip-range="10.1.0.0/16" \
				--etcd-servers="${CLUSTER_ETCD_SERVERS}" \
				--token-auth-file="/dev/null" \
				--insecure-bind-address=${LOCAL_ETCD_IP} \
				--advertise-address=${CLUSTER_MASTER_IP} \
				--admission-control=AlwaysAdmit
		

[Install] 
WantedBy=multi-user.target
EOL




# enable / start the service
sudo systemctl enable /etc/systemd/system/kubernetesApiServer-container.service
sudo systemctl start kubernetesApiServer-container.service



echo "+ Starting Kubernetes Scheduler"


sudo touch /etc/systemd/system/kubernetesScheduler-container.service


cat << EOL | sudo tee --append /etc/systemd/system/kubernetesScheduler-container.service
[Unit]  
Description=Kubernetes-Scheduler
After=docker.service 
Requires=docker.service 

[Service] 

TimeoutStartSec=5 
ExecStartPre=-/usr/bin/docker kill scheduler
ExecStartPre=-/usr/bin/docker rm scheduler
ExecStart=/usr/bin/docker run  -d \
				--net=host \
				--name scheduler gcr.io/google_containers/hyperkube:v1.2.4 \
				/hyperkube scheduler \
				--master="${CLUSTER_MASTER_IP}:8080"



[Install] 
WantedBy=multi-user.target
EOL




# enable / start the service
sudo systemctl enable /etc/systemd/system/kubernetesScheduler-container.service
sudo systemctl start kubernetesScheduler-container.service







echo "+ Starting Kubernetes Controller Manager"



sudo touch /etc/systemd/system/kubernetesControllerManager-container.service


cat << EOL | sudo tee --append /etc/systemd/system/kubernetesControllerManager-container.service
[Unit]  
Description=Kubernetes-Scheduler
After=docker.service 
Requires=docker.service 

[Service] 

TimeoutStartSec=5 
ExecStartPre=-/usr/bin/docker kill controller-manager
ExecStartPre=-/usr/bin/docker rm controller-manager
ExecStart=/usr/bin/docker run  -d   \
				--net=host \
				--name  controller-manager gcr.io/google_containers/hyperkube:v1.2.4 \
				/hyperkube controller-manager \
				--master="${CLUSTER_MASTER_IP}:8080" \
				--cluster-cidr="10.4.0.0/14" 
				


[Install] 
WantedBy=multi-user.target
EOL




# enable / start the service
sudo systemctl enable /etc/systemd/system/kubernetesControllerManager-container.service
sudo systemctl start kubernetesControllerManager-container.service




