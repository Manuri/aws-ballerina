#!bin/bash

echo "Resource deletion script is being executed !"
echo "First argument"
echo ${1}
DIR=${2}
echo $DIR
ls ${DIR}

# Read configuration into an associative array
declare -A infra_cleanup_config
# IFS is the 'internal field separator'. In this case, your file uses '='
IFS="="
while read -r key value
do
     infra_cleanup_config[$key]=$value
done < ${DIR}/infrastructure-cleanup.properties
unset IFS

#delete kubernetes services
services_to_be_deleted=${infra_cleanup_config[ServicesToBeDeleted]}
IFS=',' read -r -a services_array <<< ${services_to_be_deleted}
unset IFS

for service in "${services_array[@]}"
do
   echo "Deleting $service"
   kubectl delete svc ${service}
done

#delete database
db_identifier=${infra_cleanup_config[DatabaseName]}
aws rds delete-db-instance --db-instance-identifier "$db_identifier" --skip-final-snapshot
echo "rds deletion triggered"

#delete cluster resources
cluster_name=${infra_cleanup_config[ClusterName]}
#aws cloudformation delete-stack --stack-name=EKS-$cluster_name-DefaultNodeGroup
#aws cloudformation delete-stack --stack-name=EKS-$cluster_name-ControlPlane
#aws cloudformation delete-stack --stack-name=EKS-$cluster_name-ServiceRole
#aws cloudformation delete-stack --stack-name=EKS-$cluster_name-VPC

aws cloudformation delete-stack --stack-name "${cluster_name}-worker-nodes"
aws eks delete-cluster --name "${cluster_name}"
aws wait cluster-deleted --cluster-identifier "${cluster_name}"
aws eks describe-cluster --name "${cluster_name}" --query "cluster.status"
aws cloudformation delete-stack --stack-name "${cluster_name}"


#eksctl delete cluster --name=$cluster_name
echo " cluster resources deletion triggered"
