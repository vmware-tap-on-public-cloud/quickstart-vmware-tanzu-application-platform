#!/usr/bin/env bash

set -ex

pushd "$tap_dir/src/inputs"
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-build.yaml" ./tap-values-build.yaml
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-run.yaml" ./tap-values-run.yaml
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-iterate.yaml" ./tap-values-iterate.yaml
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-view.yaml" ./tap-values-view.yaml
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-single.yaml" ./tap-values-single.yaml
echo "Logging script input parameters"
echo ClusterArch ${ClusterArch}
echo BuildClusterBuildServiceArn ${BuildClusterBuildServiceArn}
echo BuildClusterWorkloadArn ${BuildClusterWorkloadArn}
echo IterateClusterBuildServiceArn ${IterateClusterBuildServiceArn}
echo IterateClusterWorkloadArn ${IterateClusterWorkloadArn}
echo BuildClusterName ${BuildClusterName}
echo RunClusterName ${RunClusterName}
echo ViewClusterName ${ViewClusterName}
echo IterateClusterName ${IterateClusterName}
cat <<EOF > ./user-input-values.yaml
#@data/values
---
tanzunet:
  server: ${TanzuNetRegistryServer}
  relocate_images: "${TanzuNetRelocateImages}"
  secrets:
    credentials_arn: ${TanzuNetSecretCredentials}
cluster_essentials_bundle:
  bundle: ${TanzuNetRegistryServer}/${ClusterEssentialsBundleRepo}
  file_hash: ${ClusterEssentialsBundleFileHash}
  version: ${ClusterEssentialsBundleVersion}
tap:
  name: tap
  namespace: tap-install
  repository: ${TanzuNetRegistryServer}/${TAPRepo}
  version: ${TAPVersion}
cluster:
  arch: ${ClusterArch}
  name: ${EKSClusterName}
buildservice:
  build_cluster_arn: ${BuildClusterBuildServiceArn}
  iterate_cluster_arn: ${IterateClusterBuildServiceArn}
dns:
  domain_name: ${TAPDomainName}
  zone_id: ${PrivateHostedZone}
repositories:
  tap_packages: ${TAPPackagesRepo_RepositoryUri}
  cluster_essentials: ${TAPClusterEssentialsBundleRepo_RepositoryUri}
  build_service: ${TAPBuildServiceRepo_RepositoryUri}
  workload:
    name: ${SampleAppName}
    namespace: ${SampleAppNamespace}
    repository: ${TAPWorkloadRepo_RepositoryUri}
    bundle_repository: ${TAPWorkloadBundleRepo_RepositoryUri}
    build_cluster_arn: ${BuildClusterWorkloadArn}
    iterate_cluster_arn: ${IterateClusterWorkloadArn}
EOF
popd
pushd "$tap_dir/src/resources"
aws s3 cp --no-progress --recursive --exclude '*' --include '*.yaml' "${QSS3BucketPath}/src/resources/" .
cat <<EOF > ./workload-aws.yaml
${SampleAppConfig}
EOF
popd
chown -R $user:$user "$tap_dir"
echo "Installing pivnet CLI..."
wget -O "$tap_dir/downloads/pivnet" "https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PivNetVersion}/pivnet-linux-$(dpkg --print-architecture)-${PivNetVersion}"
install -o $user -g $user -m 0755 "$tap_dir/downloads/pivnet" /usr/local/bin/pivnet
echo "Installing Tanzu CLI and Staging Tanzu-cluster-essentials..."
su - $user -c "$tap_dir/src/install-tools.sh"
echo TanzuNetRelocateImages ${TanzuNetRelocateImages}
if [[ "${TanzuNetRelocateImages}" == "Yes" ]]
then
  echo "Creating local copies of key TAP container repos per VMware best practices..."
  su - $user -c "$tap_dir/src/tap-relocate.sh"
fi
echo "Installing Tanzu Application Platform..."
echo ClusterArch ${ClusterArch}
if [[ "${ClusterArch}" == "multi" ]]
then
  echo "Setup TAP Multiple Clusters..."
  su - $user -c "$tap_dir/src/tap-main.sh -c install view"
  su - $user -c "$tap_dir/src/tap-main.sh -c install run"
  su - $user -c "$tap_dir/src/tap-main.sh -c install build"
  su - $user -c "$tap_dir/src/tap-main.sh -c install iterate"
  su - $user -c "$tap_dir/src/tap-main.sh -c prepview view"
  cfnSignal 0 "${SignalTAPInstallURL}"

  su - $user -c "$tap_dir/src/tap-main.sh -c installwk iterate"
  su - $user -c "$tap_dir/src/tap-main.sh -c installwk build"
  su - $user -c "$tap_dir/src/tap-main.sh -c installwk run"
  echo "wait till the workload to go through the supply-chain (8mins)"
  sleep 480
  cfnSignal 0 "${SignalTAPWorkloadURL}"

  su - $user -c "$tap_dir/src/tap-main.sh -c runtests run"
  su - $user -c "$tap_dir/src/tap-main.sh -c runtests iterate"
  cfnSignal 0 "${SignalTAPTestsURL}"
else
  echo "Setup TAP Single Cluster..."
  su - $user -c "$tap_dir/src/tap-main.sh -c install single"
  cfnSignal 0 "${SignalTAPInstallURL}"

  su - $user -c "$tap_dir/src/tap-main.sh -c installwk single"
  echo "wait till the workload to go through the supply-chain (8mins)"
  sleep 480
  cfnSignal 0 "${SignalTAPWorkloadURL}"

  su - $user -c "$tap_dir/src/tap-main.sh -c runtests single"
  cfnSignal 0 "${SignalTAPTestsURL}"
fi
echo "Completed successfully!"
