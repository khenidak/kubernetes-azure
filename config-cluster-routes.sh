#!/bin/bash
CURRENT_NODE_IP=$(ifconfig eth0 | grep 'inet' | cut -d: -f2 | awk '{print $2}')


function isInRoutingTable() {

   p="$1"
   if [ "$CURRENT_NODE_IP" == "${p}" ]
   then
	echo "1"
	return;
   fi

    sudo route | grep "${p}" > /dev/null && echo "1" || echo "0"



}


#sudo route del -net 10.4.3.0 netmask 255.255.255.0 gw 10.4.3.0 dev eth0
#sudo route add -net 10.4.3.0 netmask 255.255.255.0 gw 10.4.3.0 dev eth0



CURRENT_CLUSTER_NODES_NAMES=$(./kubernetes/cluster/kubectl.sh get nodes --server=http://10.0.0.4:8080 | sed -n '1!p' | awk -F " " '{print $1}')


NODES_NAME=(${CURRENT_CLUSTER_NODES_NAMES//$'\n'/ })




for index in "${!NODES_NAME[@]}"
do
    THIS_NODE_IP="`host ${NODES_NAME[index]} | awk '/has address/ { print $4 }'`"
	IN_ROUTE_TABLE=$(isInRoutingTable "${THIS_NODE_IP}")

	echo "+ Node with name:${NODES_NAME[index]} and ip:${THIS_NODE_IP} in routing table:${IN_ROUTE_TABLE} "
	if [ "$IN_ROUTE_TABLE" == '0' ]
	then
		echo "+ Node with name:${NODES_NAME[index]} and ip:${THIS_NODE_IP} added to routing table netmask 255.255.255.0 GATEWAY:${THIS_NODE_IP}"
		sudo route add -net ${THIS_NODE_IP} netmask 255.255.255.0 gw ${THIS_NODE_IP} dev eth0
	fi
done




