Use image debian-12-nocloud-arm64-20250316-2053.qcow2
Set timeout=0 on /boot/grub/grub.cfg
Install containerd

```
Configure config.toml
root@localhost:~# cat /etc/containerd/config.toml
version = 2

[grpc]
  tcp_address = "0.0.0.0:35000"

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/usr/lib/cni"
      conf_dir = "/etc/cni/net.d"
  [plugins."io.containerd.internal.v1.opt"]
    path = "/var/lib/containerd/opt"



Install docker on raspios:


# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Add the repository to Apt sources:
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker image save isolated-vm -o isolated-vm.tar
ctr --address /run/k3s/containerd/containerd-crismux.sock -n=k8s.io images import isolated-vm.tar
ctr --address ///run/k3s/containerd/containerd-crismux.sock images list
ctr --address /run/k3s/containerd/containerd-crismux.sock -n=k8s.io images import add-crismux.tar
ctr --address ///run/k3s/containerd/containerd-crismux.sock images list
```
