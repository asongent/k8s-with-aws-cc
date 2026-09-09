# Add the AWS cloud-provider Helm repository
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
helm repo update

# Install the AWS Cloud Controller Manager
helm install aws-cloud-controller-manager aws-cloud-controller-manager/aws-cloud-controller-manager \
  --namespace kube-system \
  --set args="{--v=2,--cloud-provider=aws,--configure-cloud-routes=false}"


echo 'KUBELET_EXTRA_ARGS="--cloud-provider=external --node-ip='$(hostname -I | awk '{print $1}')'"' | sudo tee /etc/default/kubelet 
sudo systemctl daemon-reload
sudo systemctl restart kubelet