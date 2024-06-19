# script para configurar el nodo trabajador de un cluster en kubernetes

echo "preparando el nodo....."
sudo timedatectl set-timezone America/Hermosillo

sudo hostnamectl set-hostname nodo1

# asignación de nombres provisional en lo que se configura el DNS
echo "IP master master" | sudo tee -a /etc/hosts
echo "mi_IP worker1 worker1" | sudo tee -a /etc/hosts
echo "mi_IP worker2 worker2" | sudo tee -a /etc/hosts
echo "mi_IP worker3 worker3" | sudo tee -a /etc/hosts

sudo systemctl restart systemd-hostnamed

sudo swapoff -a

sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay

sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "actualizando e instalando paquetes....."
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates containerd.io 
#para conectar con NFS server
sudo apt install nfs-common

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1

sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O

echo "uniendo al k8s master..."
#la siguiente linea la proporciona el nodo maestro al finalizar la instalación de kubernetes
kubeadm join master:6443 --token  aquí-va-el token --discovery-token-ca-cert-hash sha256: aquí-va-la-clave-sha

kubectl apply -f calico.yaml

# ufw firewall
sudo apt install ufw
sudo ufw allow 10251/tcp
sudo ufw allow 10255/tcp
sudo ufw reload

echo "script finalizado"
