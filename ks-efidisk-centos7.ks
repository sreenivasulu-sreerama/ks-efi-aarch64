# https://www.centosblog.com/centos-7-minimal-kickstart-file/
#
# Repos for aarch64 are at:
#  https://mirrors.aliyun.com/centos-altarch/7/os/aarch64/
#
# The boot iso is downloaded from:
#  https://mirrors.aliyun.com/centos-altarch/7/os/aarch64/images/boot.iso"

lang en_US.UTF-8
keyboard us
timezone America/Los_Angeles
selinux --disabled
firewall --service=ssh,ntp
services --enabled=sshd 
eula --agreed
network --bootproto=dhcp --device=eth0 --noipv6 --activate
rootpw --plaintext tigris

# Setup for EFI
bootloader --append="console=ttyAMA0,115200n8"

# input is CDROM and write to /dev/vdc
# The drive composition is as follows
#  vda - boot.iso CD-ROM image
#  vdb - OEMDEV volume to provide kickstart configuration (this file)
#  vdc - The disk we are attempting to bake
ignoredisk --only-use=vdc
zerombr
clearpart --drives=vdc --all --initlabel
part /boot/efi --fstype=efi --size=200
part /boot --fstype=ext4 --size=512
part / --fstype ext4 --size 5120 --grow
shutdown

url  --url=https://mirrors.aliyun.com/centos-altarch/7/os/aarch64/
repo --name=base --baseurl=https://mirrors.aliyun.com/centos-altarch/7/os/aarch64/
repo --name=updates --baseurl=https://mirrors.aliyun.com/centos-altarch/7/updates/aarch64/
repo --name=extras --baseurl=https://mirrors.aliyun.com/centos-altarch/7/extras/aarch64/
repo --name=epel --baseurl=https://mirrors.aliyun.com/epel/7/aarch64/
 
%packages --instLangs=en_US
@core
%end

