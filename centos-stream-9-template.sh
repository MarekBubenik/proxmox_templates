#!/bin/bash
# 
#
# Virt-customize command is provided by libguestfs-tools package
# sudo apt install libguestfs-tools

file="./secrets/pass"

# Vars for template
# =================
imageURL=https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2	#Link to the cloud image
IMAGE=CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2									#The name of the cloud image downloaded as stored locally in the system
TID=999															#The ID of the template to be created
TNAME=CentOS-9-Stream-Template												#The name assigned to the template being created
SIZE=50G 														#Default root disk size
BRIDGE=vmbr0 														#Default network bridge name
RAM=2048 														#Default VM Ram size
CORES=2 														#Default CPU cores
STORAGE=local-lvm 													#Storage pool name to use

# Vars for cloud-init
# ===================
CUSER=ansbot														#Cloud-init user
CPASS=$(cat "$file")													#CloudInit User password to be injected

# Download image
# ==============
wget $imageURL

# Customize image using virt-customize
# ====================================
virt-customize -a $IMAGE --install 'vim,bash-completion,wget,curl,unzip,qemu-guest-agent git'				#Install packages
virt-customize -a $IMAGE --run-command 'systemctl enable qemu-guest-agent'						#Enable qemu guest agent
virt-customize -a $IMAGE --timezone "Europe/Prague"									#Set timezone
virt-customize -a $IMAGE --run-command 'sed -i "s/.*PermitRootLogin.*/PermitRootLogin no/g"  /etc/ssh/sshd_config'	#Disable root ssh
virt-customize -a $IMAGE --run-command ' sed -i "s/^SELINUX=.*/SELINUX=disabled/g" /etc/selinux/config'			#Disable SELinux

# Create OS template 
# ==================
qemu-img resize $IMAGE $SIZE												#Resize image
qm create $TID --memory $RAM --cores $CORES --net0 virtio,bridge=$BRIDGE --scsihw virtio-scsi-pci --cpu host		#Create skeleton OS template
qm importdisk $TID $IMAGE $STORAGE											#Import the base image we customized into the actual VM storage disk
#qm set $TID --scsihw virtio-scsi-pci --virtio0 $STORAGE:$TID/vm-$TID-disk-0.raw					
qm set $TID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$TID-disk-0							#Attach the disk into the VM
qm set $TID --serial0 socket --vga serial0										#Enable serial console for the virtual machine
qm set $TID --agent 1													#Enable QEMU guest agent
qm set $TID --boot c --bootdisk virtio0											#Change boot order to start with SCSI or VirtIO block device

# Attach cloud init image and create template
# ===========================================
qm set $TID --ide2 $STORAGE:cloudinit											#Attach cloud init image
qm set $TID --sshkey /root/proxmox_templates/secrets/anskey.pub								#Inject ssh pub keys
qm set $TID --ipconfig0 ip=dhcp --cipassword="$CPASS" --ciuser=$CUSER							#Set default networking IP assignment to DHCP, and set Cloud Init user password
qm set $TID --name $TNAME												#Assign a name to the VM

qm template $TID													#Convert the Virtual Machine into template


