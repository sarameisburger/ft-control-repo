#!/bin/bash
# Note: this script does not randomize uuid for the classification group it creates, so it will create/replace the same group everytime instead of creating a new group
autosign_example_class=autosign_example
alternate_environment=dev
all_nodes_id='00000000-0000-4000-8000-000000000000'
roles_group_id='235a97b3-949b-48e0-8e8a-000000000666'
dev_env_group_id='235a97b3-949b-48e0-8e8a-000000000888'
autosign_group_id='235a97b3-949b-48e0-8e8a-000000000999'

#
# Configuration we can detect
#
master_hostname=$(/opt/puppetlabs/bin/puppet config print certname)
key=$(/opt/puppetlabs/bin/puppet config print hostprivkey)
cert=$(/opt/puppetlabs/bin/puppet config print hostcert)
cacert=$(/opt/puppetlabs/bin/puppet config print localcacert)

#
# Do some error checking first before running the script
#
error_checking()
{
  # Check to see if user running script has root privs
  if (( $EUID != 0 )); then
      echo "ERROR: This script should only be run by the root user or via sudo."
      exit 1
  fi

  # Check to see if script is being run on a puppet master
  if [ ! -f /opt/puppetlabs/server/bin/puppetserver ]; then
    echo "ERROR: This script should only be run by the root user or via sudo."
    exit 1
  fi

}

error_checking

#
# Determine the uuids for groups that are created during PE install but with randomly generated uuids
#
find_guid()
{
  echo $(curl -s https://$master_hostname:4433/classifier-api/v1/groups --cert $cert --key $key --cacert $cacert | python -m json.tool |grep -C 2 "$1" | grep "id" | cut -d: -f2 | sed 's/[\", ]//g')
}

production_env_group_id=`find_guid "Production environment"`
echo "\"Production environment\" group uuid is $production_env_group_id"
agent_specified_env_group_id=`find_guid "Agent-specified environment"`
echo "\"Agent-specified environment\" group uuid is $agent_specified_env_group_id"
pemaster_group_id=`find_guid "PE Master"`

date_string=`date +%Y-%m-%d:%H:%M:%S`
echo "Backing up existing contents of /etc/puppetlabs/code to $date_string"
cp -R /etc/puppetlabs/code /etc/puppetlabs/code_backup_$date_string

#
# Create an "Autosign" classification group to set up autosign example and vro-plugin-user
#
echo "Creating the Autosign config group"
curl -s -X PUT -H 'Content-Type: application/json' \
  --key $key \
  --cert $cert \
  --cacert $cacert \
  -d '
  {
    "name": "Autosign config",
    "parent": "'$all_nodes_id'",
    "rule":
      [ "and",
        [ "=",
          [ "trusted", "certname" ],
          "'$master_hostname'"
        ]
      ],
    "classes": { "'$autosign_example_class'": {} }
  }' \
  https://$master_hostname:4433/classifier-api/v1/groups/$autosign_group_id | python -m json.tool
echo
#
# Add 64 bit Windows agent installer to pe_repo
#
echo "Adding 64 bit Windows agent installer to pe_repo in PE Master group"
curl -s -X POST -H 'Content-Type: application/json' \
  --key $key \
  --cert $cert \
  --cacert $cacert \
  -d '
  {
    "classes": { "pe_repo::platform::windows_x86_64": {} }
  }' \
  https://$master_hostname:4433/classifier-api/v1/groups/$pemaster_group_id | python -m json.tool
echo
#
# Create a "Roles" classification group so that the integration role groups are organized more cleanly
#
echo "Creating the Roles group"
curl -s -X PUT -H 'Content-Type: application/json' \
  --key $key \
  --cert $cert \
  --cacert $cacert \
  -d '
  {
    "name": "Roles",
        "parent": "'$all_nodes_id'",
        "classes": {}
  }' \
  https://$master_hostname:4433/classifier-api/v1/groups/$roles_group_id | python -m json.tool
echo
#
# Create a role groups for each role class
#
for file in /etc/puppetlabs/code/environments/production/site/role/manifests/*; do
  basefilename=$(basename "$file")
  role_class="role::${basefilename%.*}"
  echo "Creating the \"$role_class\" classification group"

  curl -s -X POST -H "Content-Type: application/json" \
  --key    $key \
  --cert   $cert \
  --cacert $cacert \
  -d '
  {
    "name": "'$role_class'",
    "parent": "'$roles_group_id'",
    "environment": "production",
    "rule":
     [ "and",
       [ "=",
         [ "trusted", "extensions", "pp_role" ],
         "'$role_class'"
       ]
     ],
    "classes": { "'$role_class'": {} }
  }' \
  https://$master_hostname:4433/classifier-api/v1/groups
done
echo
#
# Create alternate_environment environment group
#
echo "Creating the \"$alternate_environment\" environment group"
curl -s -X PUT -H "Content-Type: application/json" \
--key    $key \
--cert   $cert \
--cacert $cacert \
-d '
{
  "name": "'$alternate_environment' environment",
  "parent": "'$production_env_group_id'",
  "environment_trumps": true,
  "environment": "'$alternate_environment'",
  "rule":
    [ "and",
      [ "=",
        [ "trusted", "extensions", "pp_environment" ],
        "'$alternate_environment'"
      ]
    ],
  "classes": {}
}' \
https://$master_hostname:4433/classifier-api/v1/groups/$dev_env_group_id | python -m json.tool
#
# Update the "Agent-specified environment" group so that pp_environment=agent-specified works as expected
#
echo "Updating \"Agent-specified environment\" group to use pp_environment in its matching rules"
curl -s -X PUT -H "Content-type: application/json" \
--key    $key \
--cert   $cert \
--cacert $cacert \
-d '
{
  "name": "Agent-specified environment",
  "parent": "'$production_env_group_id'",
  "environment_trumps": true,
  "rule":
    [ "and",
      [ "=",
        [ "trusted", "extensions", "pp_environment" ],
        "agent-specified"
      ]
    ],
  "environment": "agent-specified",
  "classes": {}
}' \
https://$master_hostname:4433/classifier-api/v1/groups/$agent_specified_env_group_id | python -m json.tool
echo
