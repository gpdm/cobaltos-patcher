#!/bin/bash

# define vars
nfsroot=/mnt/cdrom1/live/nfsroot-x86/
target=/mnt/target


# check if /mnt/cdrom1 contains the RaQ 4 ISO
if [ ! -d ${nfsroot}/3000R_3.148 ]; then
	echo "ERROR: Didn't find the Cobalt OS RaQ 3 CD mounted at /mnt/cdrom1."
	echo "       Make sure it's mounted and try again"
	exit 1
fi


# setup the chroot
#
mount -t tmpfs -o size=50M tmpfs ${nfsroot}/tmp
mount -o bind /dev ${nfsroot}/dev
mount -t proc proc ${nfsroot}/proc


# enter chroot to run Cobalt installer
#
chroot ${nfsroot} /bin/bash <<INSTALL

cd /3000R_3.148/installer
DEST_DEV=/dev/hda TMP_DIR=/tmp NET_BUILD=yes MNT_DIR_CHK=no PROJ_DIR=/3000R_3.148 PRODUCT=3000R ./build_release

echo "NOTICE: the command above may show an error on finishing, but that's OK. You're safe to ignore it!"

INSTALL
#end of here-file#


# cleanup the chroot
#
umount ${nfsroot}/tmp 
umount ${nfsroot}/dev
umount ${nfsroot}/proc


# mount the target file system
#
mkdir ${target}
mount /dev/hda1 ${target}
mount /dev/hda3 ${target}/var
mount -o bind /dev ${target}/dev
mount -t proc proc ${target}/proc


# prepare lilo.conf in target file system
#
cat<<LILO_CONF>${target}/etc/lilo.conf
boot = /dev/hda
delay = 50
vga = normal
 
image = /boot/bzImage-2.2.12C5
  root = /dev/hda1
  label = CobaltOS
  append = "console=tty0"
  read-only

image = /boot/bzImage-2.2.12C5
  root = /dev/hda1
  label = CobaltOS-rescue
  append = "init=/bin/sh console=tty0"
  read-only
LILO_CONF
#end of here-file#


# copy RPMs to target file system
#
find rpms/ -name '*.rpm' -exec cp {} ${target}/tmp \;


# perform actions in target file system:
# setup RPMs and linux source
#
chroot ${target} /bin/bash <<RPMSETUP

# install RPMs
#
cd /tmp
rpm --force -i *.rpm


# update link to linux source
#
cd /usr/src
rm linux
ln -s linux-2.2.12C5 linux

RPMSETUP
#end of here-file#


# update kernel config
#
sed -i.bak -e 's/CONFIG_MODVERSIONS=y/# CONFIG_MODVERSIONS is not set/g;s/CONFIG_COBALT_GEN_III=y/# CONFIG_COBALT_GEN_III is not set/g;s/# CONFIG_APM is not set/CONFIG_APM=y\nCONFIG_APM_IGNORE_USER_SUSPEND=n\nCONFIG_APM_DO_ENABLE=y\nCONFIG_APM_CPU_IDLE=y\nCONFIG_APM_DISPLAY_BLANK=y\nCONFIG_APM_POWER_OFF=y\nCONFIG_APM_IGNORE_MULTIPLE_SUSPEND=y\nCONFIG_APM_IGNORE_SUSPEND_BOUNCE=y\nCONFIG_APM_RTC_IS_GMT=y\nCONFIG_APM_ALLOW_INTS=y/g;s/CONFIG_COBALT_BWMGMT=y/# CONFIG_COBALT_BWMGMT is not set/g;s/CONFIG_COBALT_LCD=y/# CONFIG_COBALT_LCD is not set/g;s/# CONFIG_VGA_CONSOLE is not set/CONFIG_VGA_CONSOLE=y/g;s/# CONFIG_VIDEO_SELECT is not set/CONFIG_VIDEO_SELECT=y/g' ${target}/usr/src/linux/.config


# enable the VTYs
#
sed -i.bak -re 's|^(1:12345:respawn:).*mgetty.*|\1/sbin/mingetty tty1|g;s|^#([2-6]:2345:respawn:.*)|\1|g' ${target}/etc/inittab


# update resolv.conf
# NOTE: the nameserver is QUAD-9
#
cat<<RESOLV_CONF>${target}/etc/resolv.conf
search cobalt.local
nameserver 9.9.9.9
RESOLV_CONF
#end of here-file#


# /etc/sysconfig/network
# NOTE: the gateway used is VirtualBox's default from the 10.254.0.0/29 NAT network
#
cat<<NETWORK>${target}/etc/sysconfig/network
NETWORKING=yes
FORWARD_IPV4=no
HOSTNAME=vraq3.cobalt.local
GATEWAYDEV=eth0
GATEWAY=10.254.0.1
NETWORK
#end of here-file#


# /etc/sysconfig/network-scripts/eth0
# NOTE: the addressing matches VirtualBox's 10.254.0.0/29 NAT network
#
cat<<ETH0>${target}/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
ONBOOT=yes
IPADDR=10.254.0.3
NETWORK=10.254.0.0
NETMASK=255.255.255.248
BROADCAST=10.254.0.7
ETH0
#end of here-file#


# /etc/hosts
# NOTE: the addressing matches VirtualBox's 10.254.0.0/29 NAT network
#
cat<<HOSTS>>${target}/etc/hosts
10.254.0.3 vraq3 vraq3.cobalt.local
HOSTS
#end of here-file#




# perform actions in target file system:
# - build kernel and modules
#
chroot ${target} /bin/bash <<KERNEL

# rebuild kernel and modules and install them
#
cd /usr/src/linux
make oldconfig && make dep && make clean && make bzImage && make modules && make modules_install
cp arch/i386/boot/bzImage /boot/bzImage-2.2.12C5

KERNEL
#end of here-file#


# perform actions in target file system:
# - enable eth0 kernel module
# - disable lcd utilitiew
# - install lilo
#
chroot ${target} /bin/bash <<FINETUNE

# enable network drive for VirtualBox
#
echo alias eth0 pcnet32 >> /etc/modules.conf


# disable the LCD utils
#
cd /sbin
for x in lcd*; do
  ln -sf /bin/true $x
done


# install lilo
#
lilo -C /etc/lilo.conf


FINETUNE
#end of here-file#


# unmount filesystems
#
umount ${target}/proc
umount ${target}/dev
umount ${target}/var
umount ${target}


cat<<FINISHED
***********************************
INSTALLATION COMPLETED
***********************************

Please disconnect the ISO files from all virtual drives,
and reboot.

FINISHED

exit 0
