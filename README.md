# cobaltos-patcher
Former Cobalt Network's / Sun Microsystem's RaQ OS does not run in VirtualBox.
This repo provides everything to patch it for running in VirtualBox.


# Too lazy? VM image is here!

Yes, a ready-to-run VM image is provided as well, and hosted on [archive.org](https://www.archive.org).
So to just get up & running, follow the instructions provided on [Cobalt RaQ Virtual Machine](https://archive.org/details/virtual-cobalt-raq-3-appliance).


# Do it yourself

The following instructions assume you're running VirtualBox on a UNIX-like environment, such as MacOS or Linux.
On Windows, some steps may a bit different.

## Prerequisites

You need some stuff to make this work:

 * [VirtualBox](http://www.virtualbox.org)
 * The Cobalt Networks [RaQ 3 restore CD](https://archive.org/download/cobalt_networks_ftp_mirror/raq3.iso) ISO file
 * [Knoppix Live 3.7](https://sourceforge.net/projects/knoppix-mirror/files/knoppix/KNOPPIX_V3.7-2004-12-08-EN.iso/download) ISO file
 * [Cobalt OS Patcher](https://github.com/gpdm/cobaltos-patcher/raw/main/cobaltos-patcher.iso) ISO file


## Preparing VirtualBox

### Prepare NAT network

Create a virtual NAT network as shown.
Use the IP addresses as shown, as these will be referenced during the staging procedure.

```
VBoxManage natnetwork add --enable --netname "vCobaltRaq" --network 10.254.0.0/29 --dhcp on --ipv6=off
VBoxManage natnetwork modify --netname "vCobaltRaq" --port-forward-4="Rule 1:tcp:[]:2022:[10.254.0.3]:22"
VBoxManage natnetwork modify --netname "vCobaltRaq" --port-forward-4="Rule 2:tcp:[]:80:[10.254.0.3]:80"
VBoxManage natnetwork modify --netname "vCobaltRaq" --port-forward-4="Rule 3:tcp:[]:81:[10.254.0.3]:81"
VBoxManage dhcpserver add --network vCobaltRaq --server-ip 10.254.0.2 --netmask 255.255.255.248 --lower-ip 10.254.0.3 --upper-ip 10.254.0.3 --enable
```

This will map the Ports 22, 80 and 81 inside the VM to your `localhost:` (127.0.0.1) IP address.
This is required later on when interacting with the VM over the network.


### Import the Template VM

Get the OVA file from here:

```
wget https://github.com/gpdm/cobaltos-patcher/raw/main/Cobalt%20Emulation.ova
```

Import the OVA file like this:

```
VirtualBox "Cobalt Emulation.ova"
```

This will open the import assistant.
Just save the VM as is.


### Attach the ISO files

You can either do this via the UI, or via the CLI.

Attach the ISO files.

 * The KNOPPIX ISO goes to the primary DVD drive
 * The RAQ ISO goes to the secondary DVD drive
 * The CobaltOS-Patcher ISO goes to the third DVD drive

Via the CLI:

```
wget https://archive.org/download/cobalt_networks_ftp_mirror/raq3.iso
wget https://sourceforge.net/projects/knoppix-mirror/files/knoppix/KNOPPIX_V3.7-2004-12-08-EN.iso/download
wget https://github.com/gpdm/cobaltos-patcher/raw/main/cobaltos-patcher.iso 
VBoxManage storageattach "Cobalt Emulation" --storagectl IDE --port 0 --device 1 --type dvddrive --medium "KNOPPIX_V3.7-2004-12-08-EN.iso"
VBoxManage storageattach "Cobalt Emulation" --storagectl IDE --port 1 --device 0 --type dvddrive --medium "raq4.iso"
VBoxManage storageattach "Cobalt Emulation" --storagectl IDE --port 1 --device 1 --type dvddrive --medium "cobaltos-patcher.iso"
```

## Start the VM

Now, start the VM.
If you followed the steps above, it should boot right away into KNOPPIX.

Type this at the prompt to boot into english KNOPPIX (otherwise it will default to a `german` languange UI):

```
knoppix lang=us
```

## Run the Patcher

Open a terminal and run these commands:

```
su root
cd /mnt/cdrom2
./cobaltos_patcher.sh
```

This will perform all steps. Be aware you will see many errors, i.e.
 * LCD is not present
 * failed `quotaoff`and `quotaon` commands
 * missing log files, like `/var/cobalt/sauce.log`
 * hostname lookup failures
 * and a few others

This is expected and can be safely ignored.

Also, towards the end of the RPM installation, the procedure may appear to "hang"
during or after the `lyle super-hack` appears on screen.
It takes some time, just leave it running and it will eventually complete.


## What next?

Once the virtual RaQ 3 appliance has started-up, you may access it from your host via the NAT rules defined further above:

* localhost:2022 to access the RaQ at TCP:22 for SSH access
* localhost:80 to access the RaQ at TCP:80 for the standard webserver
* localhost:81 to access the RaQ at TCP:81 for the admin UI


# FAQ

## Why these specific network settings for NAT and DHCP?

Because I wanted to built straight forward instructions.
Hence, something that universally works without too many explanations, requires customized network settings.

Basically it works like this:

* The customer `vCobaltRaq` NAT networks defines a ingress NAT Port Mappings in order to reach SSH (TCP:22), HTTP (TCP:80) and the Admin UI (TCP:81)
* for this to work via predifinitions, we need to control which IP address will be assigned to the VM, either
** in the early phase, while running in KNOPPIX (netconfig done via DHCP)
** in the later phase, while running in CobaltOS (netconfig done via static definitions in /etc/sysconfig/network-scripts/ifcfg-eth0)
* That DHCP range `10.254.0.0/29` is thus customized to only allow one single IP to be advertised via DHCP, which is `10.254.0.3`
* This IP is also referenced in the aforementioned ingress NAT PORT Mappings

If I didn't do it like this, I'd have to explain a lot more around the entire network specific configuration.
You're free to adapt it to your likings, but be aware that the forward instructions won't tell you, where you have to specifically adapt.


## I see many errors

For sure, many are related to the original Cobalt OS installer, which is run in background.
So thins like these are totally normal and can be safely ignored:

This will perform all steps. Be aware you will see many errors, i.e.
 * LCD is not present
 * failed `quotaoff`and `quotaon` commands
 * missing log files, like `/var/cobalt/sauce.log`
 * hostname lookup failures
 * and a few others

If you believe you have seen other crucial errors, feel free to open an issue ticket.


## On the first reboot I see "read-only filesystem" errors

Yeah, not really nice, but first filesystem check will fix that.

This symptom is closely related to [No eth0 at first boot](https://github.com/gpdm/cobaltos-patcher#i-dont-have-eth0-on-the-first-boot), so you may follow the procedure outlined there as well.
  

## I see boot errors about missing "module char-major-10-140"

That's because of the LCD being removed from the newly compiled kernel.
This can be safely ignored.


## Patcher complains about not finding the CD

As noted above, the ISO files must be attached as follows.

 * The KNOPPIX ISO goes to the primary DVD drive
 * The RaQ ISO goes to the secondary DVD drive
 * The CobaltOS-Patcher ISO goes to the third DVD drive

The patcher script is not very sophisticated, and does not do auto-detection.
It simply expects the RaQ ISO file being in the /dev/cdrom1 drive.


## How long does an install take?

This depends on your host machine running the VM.
On my reference machine (2015 Quad-Core i7), it takes < 1 minute to run `cobaltos-patcher.sh`.

If you accound for the additional time to boot and reboot the VM, you can be up and running in < 5 mins!


## What is changed in comparison to the original Cobalt OS?

Only the things needed to make it boot in a VM, which are:

* the pcnet32 kernel module for eth0
* enabling the standard VGA console VTYs
* removing the Cobalt-patches from the kernel (as in: you now have a vanilla kernel compiled from the Cobalt sources, minus the Cobalt-specifics)

Other than that, no changes or adaptions were made to the OS.


## Can the Cobalt patch-sets be applied?

I didn't test that.
But it should generally work, except for the kernel.


## Do you have Cobalt OS patch-sets?

Some of them, yes.
I archived everything I could find on [cobalt_networks_ftp_mirror](https://archive.org/details/cobalt_networks_ftp_mirror).


## Why are you recompiling the kernel?

Those details are explained in further detail in the YouTube video []().

In short, the default Cobalt OS kernel depends on presence of certain hardware,
hence recompiling it is required to make it work in a standard VM.


## What is the login credentials?

It's the Cobalt OS factory defaults.

 * Username `admin`
 * Password `admin`

This works for both the system console as well as the web GUI.


## I don't have 'eth0' on the first boot

Yes, this happened to me from time to time as well.

`depmod` is already during the boot sequence, though sometimes it doesn't seem to work correctly.
Just reboot the VM once again, it should find the `pcnet32` module next time round, so eth0 should work correctly thereafter.

Alternatively, before the first boot, go into the recovery console.
Press SHIFT once the `LILO` line appears, then enter `CobaltOS-rescue`.

In the recovery console, run:

```
/sbin/fsck -y /dev/hda1 /dev/hda3 /dev/hda4
mount -o remount,rw /dev/hda1
/sbin/depmod -ae
sync
mount -o remount,ro /dev/hda1
/sbin/reboot -f
```

## I want to change the network settings

Sure, assuming you have already installed the Cobalt OS, easiest to do is via the recovery console.
At the early stage of when the `LILO` line appears, press shift for the LILO prompt.
Then enter `CobaltOS-rescue` to start a root shell.

Perform these commands as follows:

```
/sbin/fsck -y /dev/hda1
mount -o remount,rw /dev/hda1
vi /etc/resolv.conf
vi /etc/hosts
vi /etc/sysconfig/network
vi /etc/sysconfig/network-scripts/ifcfg-eth0
sync
mount -o remount,ro /dev/hda1
/sbin/reboot -f
```

Adapt the network settings to your needs.
