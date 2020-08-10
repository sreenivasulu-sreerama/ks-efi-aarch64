# ks-efi-aarch64
Prepare ARM64v8 UEFI bootable disk on x86_64 build host for CentOS 7.

This uses qemu-system-aarch64 with UEFI boot mode and builds UEFI bootable
ARM64v8 boot disk taking the boot.iso as input. The following boot ISO image
is used:
https://mirrors.aliyun.com/centos-altarch/7/os/aarch64/images/boot.iso

The following mirrors are recommended:
- https://mirrors.aliyun.com/centos-altarch/7 if attempting to build on latest CentOS 7 version.
- http://mirror.chpc.utah.edu/pub/vault.centos.org/altarch for specific CentOS 7 distro
- The reason is that the aliyun mirror while faster does not host 'repodata' for older CentOS distros for aarch64 and thus can't be used for kickstart

The following methodology is used:
- Launch a QEMU VM AARCH64 with boot.iso for AARCH64 and with UEFI boot ON
- Create disk image and use kickstart configuration to prepare that disk
- The kickstart file is provided to QEMU via OEMDRV volume
- Default QEMU SLIRP networking is configured on the host:
  https://wiki.qemu.org/Documentation/Networking
- More explanation of QEMU options are available here:
  https://wiki.gentoo.org/wiki/QEMU/Options

## qemu-system-aarch64
If building this on newer versions of Fedora (tested with Fedora32) or 
Ubuntu (tested with Ubuntu20.04), then `qemu-system-aarch64` is available
from upstream repos and can be installed using either 'dnf/apt' 
appropriately. CentOS on the other hand does not have this available
upstream yet. 

Use the following procedure to build this locally:
- GIT clone git repo at https://github.com/qemu/qemu.git
- Checkout stable release by branch/tag (I chose tag v4.1.1)
- Configure first: `./configure --no-kvm --target-list=aarch64-softmmu`
- Option `--no-kvm` is needed if building on non-AARCH64 platform 
- Build: `make`
- The sub-directory `aarch64-softmmu` will contain executable `qemu-system-aarch64`

## OVMF
The OVMF or EDK2 for AARCH64 is needed to launch VM in UEFI AARCH64 mode. This
can be picked from upstream if using Fedora32/Ubuntu20 or newer versions. In
case the `qemu-system-aarch64` is built locally, then the OVMF also should
be either built locally or downloaded from other distros. I picked the
following package and extracted the file `QEMU_EFI-pflash.raw` for use
with `qemu-system-aarch64` version 4.1.1.
https://mirrors.aliyun.com/fedora/releases/32/Everything/x86_64/os/Packages/e/edk2-aarch64-20190501stable-5.fc32.noarch.rpm

If using another file or version, the same can be provided by either editing
the script or by using `--ovmf-path` argument.

## Kickstart Configuration
The boot.iso image holds only bootable image and kickstart relies on
network to fetch the content. Adjust the repos that are defined using
`url` or `repo` in kickstart configuration file based on the need.

## Rescue mode
To debug any issues or to use boot.iso just to boot and not prepare disk,
follow these steps to boot in rescue mode:
- Replace "-V OEMDRV" in mkisofs command above to "-V TESTDRV"
- In the 'append' arguments, add the following arguments: 
- `rescue root=LABEL=CentOS\x207\x20aarch64 ro`

## Procedure
1. Clone this repo locally with network connectivity
2. Download the boot.iso file from the URL mentioned previously
3. Configure QEMU SLIRP networking as described previously
4. Get or build qemu-system-aarch64 and OVMF as described previously
5. Check for OVMF path (override via command line if needed)
6. Run command: `./ks-efidisk-centos7.sh <disk-image-filename>`
7. The VM shuts down after installation if successfully completed. 
8. Run the command to launch a VM with the new disk image: `./launch-efidisk <disk-image-filename>`

## Notes
1. Verified this on non-UEFI booted CentOS 7.7 build host
2. Built qemu locally and obtained OVM from Fedora32 repo
3. The build time is very slow compared to building x86_64 image

