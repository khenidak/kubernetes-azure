#!/bin/bash

# Core Os - does not support Extention yet (i.e. custom bootstrap script)
# This script connects to masters and configure them 

location="westus" # Resorce group location
dns_label="my-kub-cluster03" # DNS label for cluster
key_file="./keys/vmkey" # location for ssh key file
azure_user_name="azureuser" # user name to connect to the cluster
masters_count="5" # 
node_group_count=3
nodes_per_group=3


thishost="${dns_label}.${location}.cloudapp.azure.com"
COUNTER=0

while [  $COUNTER -lt $masters_count ]; do
	thisport="500${COUNTER}"

	echo "+ Performing Master Configuration on: ${thishost} on Port ${thisport} logs @ ~./bootstrap.log"
    scp -o "StrictHostKeyChecking no"  -i ${key_file} -P ${thisport}  ./bootstrap-master.sh ${azure_user_name}@${thishost}:~/ 

	echo "++ Executing Master-Bootstrap on: ${thishost} on Port ${thisport} logs @ ~./bootstrap.log"
    
	ssh -o "StrictHostKeyChecking no"  ${azure_user_name}@${thishost} -p ${thisport} -i ${key_file}  "chmod +x ./bootstrap-master.sh;  ./bootstrap-master.sh ${azure_user_name}  "

    COUNTER=`expr $COUNTER + 1` 
done

echo "+ Configuration on Masters completed, log files on each node at /home/${azure_user_name}/bootstrap.log"
echo "+ Configuring nodes via master-0"

#reset


COUNTER=0
thisport="500${COUNTER}"


#copy the script + key file to master 0
scp -o "StrictHostKeyChecking no"  -i ${key_file} -P ${thisport}  ./bootstrap-node.sh ${azure_user_name}@${thishost}:~/
scp -o "StrictHostKeyChecking no"  -i ${key_file} -P ${thisport}  ${key_file} ${azure_user_name}@${thishost}:~/vmkey 




groupcounter=0


while [  $groupcounter -lt $node_group_count ]; do
	actual_seg2_ip=`expr $groupcounter + 1`
	nodecounter=0
	while [  $nodecounter -lt $nodes_per_group ]; do
	actual_seg3_ip=`expr $nodecounter + 1`

		thisnodeaddress="11.${actual_seg2_ip}.${actual_seg3_ip}.4"
		echo "+ Performing Node Configuration on: ${thisnodeaddress}"
		
		#copy the bootstrap file to node
		ssh -o "StrictHostKeyChecking no"  ${azure_user_name}@${thishost} -p ${thisport} -i ${key_file} \
		"scp -o 'StrictHostKeyChecking no'  -i ./vmkey  ./bootstrap-node.sh ${azure_user_name}@${thisnodeaddress}:~/"

		#make it executable
		ssh -o "StrictHostKeyChecking no"  ${azure_user_name}@${thishost} -p ${thisport} -i ${key_file} \
		"ssh -o 'StrictHostKeyChecking no'  -i ./vmkey  ${azure_user_name}@${thisnodeaddress} \"chmod +x ./bootstrap-node.sh \"   "


		echo "++ Executing Node-Bootstrap On: ${thisnodeaddress}"
		#execute it
		ssh -o "StrictHostKeyChecking no"  ${azure_user_name}@${thishost} -p ${thisport} -i ${key_file} \
		"ssh -o 'StrictHostKeyChecking no'  -i ./vmkey  ${azure_user_name}@${thisnodeaddress} \" sudo systemd-run --uid=${azure_user_name} ./bootstrap-node.sh  ${azure_user_name} \" "   

    

    	nodecounter=`expr $nodecounter + 1` 
	done
	

	
    groupcounter=`expr $groupcounter + 1` 
done






echo "+ Removing keys from the master"


# ssh -o "StrictHostKeyChecking no"  ${azure_user_name}@${thishost} -p ${thisport} -i ${key_file}  "rm ./vmkey"

