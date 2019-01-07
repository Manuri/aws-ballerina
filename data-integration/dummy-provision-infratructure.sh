#!bin/bash

output_dir=$2
echo $output_dir

cluster_name="ballerina-test-cluster-data"
retry_attempts=3
config_file=~/.kube/config
echo $retry_attempts

infra_properties=$output_dir/infrastructure.properties
testplan_properties=$output_dir/testplan-props.properties

db=`cat ${testplan_properties} | grep -w DBEngine ${testplan_properties} | cut -d'=' -f2`
db_version=`cat ${testplan_properties} | grep -w DBEngineVersion ${testplan_properties} | cut -d'=' -f2`

NEW_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)

#database-name
database_name=ballerina-kubernetes-"$NEW_UUID"

# echo $kube_master
# echo $output_dir
# echo "KUBERNETES_MASTER=$kube_master" > $output_dir/k8s.properties

#retrieve the database hostname
echo "DatabaseHost=DummyHost" >> $output_dir/infrastructure.properties
echo "DatabasePort=DummyPort" >> $output_dir/infrastructure.properties
echo "DatabaseName=DummyName" >> $output_dir/infrastructure.properties
echo "DBUsername=DummyUsername" >> $output_dir/infrastructure.properties
echo "DBPassword=DummyPassword" >> $output_dir/infrastructure.properties
echo "ClusterName=$cluster_name" >> $output_dir/infrastructure.properties
