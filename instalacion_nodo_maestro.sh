# scrip para preparar nodo maestro
echo "preparando el nodo....."
sudo timedatectl set-timezone America/Hermosillo

sudo hostnamectl set-hostname master1

# asignación de nombres provisional en lo que se configura el DNS
echo "IP master master" | sudo tee -a /etc/hosts
echo "mi_IP worker1 worker1" | sudo tee -a /etc/hosts
echo "mi_IP worker2 worker2" | sudo tee -a /etc/hosts
echo "mi_IP worker3 worker3" | sudo tee -a /etc/hosts

sudo systemctl restart systemd-hostnamed

hostname

echo "swapp off....."
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

echo "repositorio docker....."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "actualizando e instalando paquetes....."
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates containerd.io 
#para conectar con NFS server
sudo apt install nfs-common
#instala utilirías
sudo apt install net-tools lsof traceroute iputils-ping tcpdump dnsutils vim htop

echo "configurando containerd....."
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

echo "repositorio de k8s....."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update

echo "instalando kubelet, kubeadm, kubectl....."
#comprobar la última versión
sudo apt install -y kubelet kubeadm=1.28.1 kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "iniciando k8s master..."
sudo kubeadm init --control-plane-endpoint=master1
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#comprobar la versión más reciente
echo "instalando red de calico ..."
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O
kubectl apply -f calico.yaml

# firewall ufw
sudo apt install ufw
sudo ufw allow 6443/tcp
sudo ufw allow 2379/tcp
sudo ufw allow 2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10251/tcp
sudo ufw allow 10252/tcp
sudo ufw allow 10255/tcp
sudo ufw reload

echo "script finalizado"
