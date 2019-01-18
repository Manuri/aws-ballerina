#!bin/bash

work_dir=`pwd`
echo $work_dir
output_dir=$2
echo $output_dir

cluster_name="ballerina-test-cluster-data-round11"
cluster_region="us-east-1"
retry_attempts=3
config_file_name=ballerina-config.yaml
config_file=$output_dir/$config_file_name
echo $retry_attempts


while [ "$STATUS" != "ACTIVE" ] && [ $retry_attempts -gt 0 ]
do
    eksctl create cluster --name "$cluster_name" --region "$cluster_region" --nodes-max 3 --nodes-min 1 --node-type t2.small --zones=us-east-1a,us-east-1b,us-east-1d --kubeconfig=${config_file}
    #Failed cluster creation - another cluster is being created, so wait for cluster to be created - This needs to be done
    #in case there are multiple test plans are created. i.e. There multiple infra combinations.
    if [ $? -ne 0 ]; then
         echo "Waiting for service role.."
         aws cloudformation wait stack-create-complete --stack-name=EKS-$cluster_name-ServiceRole
         echo "Waiting for vpc.."
         aws cloudformation wait stack-create-complete --stack-name=EKS-$cluster_name-VPC
         echo "Waiting for Control Plane.."
         aws cloudformation wait stack-create-complete --stack-name=EKS-$cluster_name-ControlPlane
         echo "Waiting for node-group.."
         aws cloudformation wait stack-create-complete --stack-name=EKS-$cluster_name-DefaultNodeGroup
    else
        #if the cluster creation is succesful , any existing config files are removed
        #if [ -f "$config_file" ];then
        #    rm $config_file
        #fi

        #current_context=$(kubectl config current-context --kubeconfig=${config_file})
        #Configure the security group of nodes to allow traffic from outside
        node_security_group=$(aws ec2 describe-security-groups --filter Name=tag:aws:cloudformation:logical-id,Values=NodeSecurityGroup --query="SecurityGroups[0].GroupId" --output=text)
        aws ec2 authorize-security-group-ingress --group-id $node_security_group --protocol tcp --port 0-65535 --cidr 0.0.0.0/0
    fi
    STATUS=$(aws eks describe-cluster --name $cluster_name --query="[cluster.status]" --output=text)
    echo "Status is "$STATUS
    retry_attempts=$(($retry_attempts-1))
    echo "attempts left : "$retry_attempts
done

#if the status is not active by this phase the cluster creation has failed, hence exiting the script in error state
if [ "$STATUS" != "ACTIVE" ];then
    echo "state is not active"
    exit 1
fi

# Check if config file exists, if it does not exist create the config file
#if [ ! -f "$config_file" ];then
#    echo "config file does not exist"
#    eksctl utils write-kubeconfig --name $cluster_name --region $cluster_region
#fi

infra_properties=$output_dir/infrastructure.properties
testplan_properties=$output_dir/testplan-props.properties

db=`cat ${testplan_properties} | grep -w DBEngine ${testplan_properties} | cut -d'=' -f2`
db_version=`cat ${testplan_properties} | grep -w DBEngineVersion ${testplan_properties} | cut -d'=' -f2`

NEW_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)

#database-name
database_name=ballerina-kubernetes-"$NEW_UUID"

##create the database

if [ "$db" == "mysql" ];then
echo "Creating a MySQL instance"
aws rds create-db-instance --db-instance-identifier "$database_name" \
    --db-instance-class db.t2.micro \
    --engine "$db" \
    --allocated-storage 10 \
    --master-username masterawsuser \
    --master-user-password masteruserpassword \
    --backup-retention-period 0\
    --engine-version "$db_version"

db_port=3306

elif [ "$db" == "sqlserver-se" ];then
echo "Creating an SQL Server instance"
aws rds create-db-instance --db-instance-identifier "$database_name" \
    --db-instance-class db.t2.micro \
    --engine "$db"  \
    --allocated-storage 20  \
    --master-username masterawsuser  \
    --master-user-password masteruserpassword \
    --backup-retention-period 0 \
    --license-model license-included \
    --engine-version "$db_version"

db_port=1433

elif [ "$db" == "oracle-se2" ];then
echo "Creating an Oracle instance"
aws rds create-db-instance --db-instance-identifier "$database_name" \
    --db-instance-class db.t2.micro  \
    --engine "$db"  \
    --allocated-storage 10  \
    --master-username masterawsuser  \
    --master-user-password masteruserpassword \
    --backup-retention-period 0 \
    --license-model license-included \
    --engine-version "$db_version"

db_port=1521
fi

#Wait for the database to become available
aws rds wait  db-instance-available  --db-instance-identifier "$database_name"
#retrieve the database hostname
echo "DatabaseHost="$(aws rds describe-db-instances --db-instance-identifier="$database_name" --query="[DBInstances][][Endpoint][].{Address:Address}" --output=text) >> $output_dir/infrastructure.properties
echo "DatabasePort=$db_port" >> $output_dir/infrastructure.properties
echo "DBUsername=masterawsuser" >> $output_dir/infrastructure.properties
echo "DBPassword=masteruserpassword" >> $output_dir/infrastructure.properties
echo "ClusterName=$cluster_name" >> $output_dir/infrastructure.properties
echo "ClusterRegion=$cluster_region">> $output_dir/infrastructure.properties
echo "ConfigFileName=$config_file_name">> $output_dir/infrastructure.properties
#echo "CurrentKubeContext=$current_context">> $output_dir/infrastructure.properties

echo "DatabaseName=$database_name" >> $output_dir/infrastructure-cleanup.properties
echo "ClusterName=$cluster_name" >> $output_dir/infrastructure-cleanup.properties
echo "ClusterRegion=$cluster_region">> $output_dir/infrastructure-cleanup.properties
