# Install docker on raspios:

```
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
```

# Get images from docker to containerd (k3s for example)

```
docker image save add-crismux -o add-crismux.tar
docker image save isolated-vm -o isolated-vm.tar
ctr --address /run/k3s/containerd/containerd-crismux.sock -n=k8s.io images import isolated-vm.tar
ctr --address ///run/k3s/containerd/containerd-crismux.sock images list
ctr --address /run/k3s/containerd/containerd-crismux.sock -n=k8s.io images import add-crismux.tar
ctr --address ///run/k3s/containerd/containerd-crismux.sock images list
```
