#!/bin/bash
set -e
group=docker
if [ $(id -gn) != $group ]; then
  echo "execute as group docker"
  exec sg $group "$0 $*"
fi

source "src/functions.sh"

function tapInstallMain {
  banner "TAP Install..."
  readUserInputs
  readTAPInternalValues
  verifyK8ClusterAccess
  parseUserInputs

  if [[ $skipinit == "true" ]]
  then
    echo "Skipping prerequisite..."
  else
    echo "Setup prerequisite..."
    installTanzuClusterEssentials
    createTapNamespace
    createTapRegistrySecret
    loadPackageRepository
  fi
  tapInstallFull
  tapWorkloadInstallFull
  printOutputParams
  echo "TAP Install Done ..."

}

function tapUninstallMain {

  banner "TAP Uninstall..."
  readUserInputs
  readTAPInternalValues
  verifyK8ClusterAccess
  parseUserInputs

  tapWorkloadUninstallFull
  tapUninstallFull
  deleteTapRegistrySecret
  deletePackageRepository
  deleteTanzuClusterEssentials
  deleteTapNamespace

  echo "TAP Uninstall Done ..."

}

function tapRelocateMain {
  banner "TAP Relocate..."
  readUserInputs
  readTAPInternalValues
  parseUserInputs
  relocateTAPPackages
  echo "TAP Relocate Done ..."

}

function tapTestPreReqs {
  banner "TAP Test PreReqs ..."
  
  readUserInputs
  readTAPInternalValues
  parseUserInputs

  echo ECR_REGISTRY_HOSTNAME $ECR_REGISTRY_HOSTNAME
  echo ECR_REGISTRY_USERNAME $ECR_REGISTRY_USERNAME
  echo ECR_REGISTRY_PASSWORD $ECR_REGISTRY_PASSWORD
  echo AWS_DOMAIN_NAME $AWS_DOMAIN_NAME
  echo CLUSTER_NAME $CLUSTER_NAME
  echo TANZUNET_REGISTRY_HOSTNAME $TANZUNET_REGISTRY_HOSTNAME
  echo TANZUNET_REGISTRY_USERNAME $TANZUNET_REGISTRY_USERNAME
  echo TANZUNET_REGISTRY_PASSWORD $TANZUNET_REGISTRY_PASSWORD
  echo PIVNET_TOKEN $PIVNET_TOKEN

  verifyK8ClusterAccess

  echo "TAP Test PreReqs Done ..."
}

#####
##### Main code starts here
#####

while [[ "$#" -gt 0 ]]
do
  case $1 in
    -f|--file)
      file="$2"
      ;;
    -c|--cmd)
      cmd="$2"
      ;;
    -s|--skipinit)
      skipinit="true"
      ;;
  esac
  shift
done

if [[ -z "$cmd" ]]
then
  cat <<EOT
  Usage: $0 -c {install | uninstall | relocate | prereqs } OR
      $0 -c {install} [-s | --skipinit]
EOT
  exit 1
fi

export GITHUB_HOME=$PWD
echo COMMAND=$cmd SKIPINIT=$skipinit GITHUB_HOME=$GITHUB_HOME
echo "This script is running as group $(id -gn)"
export DOWNLOADS=$GITHUB_HOME/downloads
export INPUTS=$GITHUB_HOME/src/inputs
export GENERATED=$GITHUB_HOME/generated
export RESOURCES=$GITHUB_HOME/src/resources

case $cmd in
"install")
  tapInstallMain
  ;;
"uninstall")
  tapUninstallMain
  ;;
"relocate")
  tapRelocateMain
  ;;
"prereqs")
  tapTestPreReqs
  ;;
esac

