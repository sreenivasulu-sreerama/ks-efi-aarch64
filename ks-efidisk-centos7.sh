#!/bin/bash
#
# The boot iso is downloaded from:
#   https://mirrors.aliyun.com/centos/7/os/x86_64/images/boot.iso
#
# This is to create EFI disk via kickstart

# usage
function usage()
{
    echo "This script can be used to create EFI bootable VM disk image"
    echo "for ARM64v8 (aarch64) architecture from LIVE boot iso image"
    echo "of Linux distro (tested with CentOS 7) while building the image"
    echo "on a x86_64 system. This script makes use of kickstart"
    echo "configuration in ks-efidisk-centos7.ks file that is currently set for"
    echo "CentOS 7, and the CentOS boot.iso file that is expected to be"
    echo "downloaded first."
    echo ""
    echo "Download boot.iso to this directory from distro mirror:"
    echo "  wget https://mirrors.aliyun.com/centos-altarch/7/os/aarch64/images/boot.iso"
    echo ""
    echo "Usage:"
    echo "./ks-efidisk-centos7.sh [--help|--size-gb|--ovmf-path] <disk-filename>"
    echo "   --help      - Display this information and exit"
    echo "   --size-gb   - Size of the disk image in GB (default:${DISKSIZEGB}GB)"
    echo "   --ovmf-path - OVMF filepath to use (default:${OVMFPATH})"
    echo ""
    return
}

# Parse arguments and apply settings accordingly
# Complete command including $0 is expected to be passed
function parse_args()
{
    local OPTS

    OPTS=$(getopt -o h --long help,size-gb:,ovmf-path: -n 'parse-options' -- "$@")
    if [ $? -ne 0 ]; then
        usage
        echo "ERROR: Incorrect option provided"
        exit 1
    fi

    eval set -- "$OPTS"
    while true; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            --size-gb)
                # Shift to argument
                shift
                DISKSIZEGB=$1
                ;;
            --ovmf-path)
                # Shift to argument
                shift
                OVMFPATH=$1
                ;;
            --)
                # End of arguments
                shift
                break
                ;;
        esac
        shift
    done

    # The disk image filename argument is must
    if [ $# -ne 2 ]; then
        usage
        echo "ERROR: Insufficient/Unexpected arguments"
        exit 1
    fi

    # Extract disk image filename
    DISKIMGNAME="$2"

    # Validate disk image size
    if [[ $DISKSIZEGB != [0-9]* ]] || \
       [ $DISKSIZEGB -lt 8 ] || [ $DISKSIZEGB -gt 200 ]; then
        echo "ERROR: Check the argument for disk size (valid range 8-200)"
        exit 1
    fi
}

# Main

# Run this in the same directory
HOMEDIR=`dirname $(readlink -m -n $0)`
CWD=$(pwd)
if [ "$HOMEDIR" != "$CWD" ]; then
    echo "Run this script in the same directory"
    exit 1
fi

# Ensure that this is x86_64 system
if [ "$(uname -m)" != "x86_64" ]; then
    usage
    exit 1
fi

# Set global defaults

# We currently use OVMF extracted from Fedora32 repo
OVMFPATH="QEMU_EFI-pflash.raw"

# Set default disk size ot 8GB
DISKSIZEGB=8

# Disk image file
DISKIMGNAME=""

# Validate and parse arguments
parse_args $0 "$@"

# The file boot.iso is expected to be present here
if [ ! -e boot.iso ]; then
    usage
    echo "ERROR: boot.iso not present"
    exit 1
fi

# Exit if OVMFPATH file is not present
if [ ! -e ${OVMFPATH} ]; then
    usage
    echo "ERROR: OVMFPATH file @${OVMFPATH} not found"
    exit 1
fi

DELPATHS="${DISKIMGNAME} OEMDRV.iso ksisofs UEFI_VARS.fd"
for DELITEM in $DELPATHS
do
    # validate first if it exists
    if [ -e $DELITEM ]; then
        lsof $DELITEM >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "${DELITEM} has open handles. Fix this first"
            exit 1
        else
            echo "Deleting current copy of: ${DELITEM}"
            \rm -rf ${DELITEM} >/dev/null 2>&1 || true
        fi
    fi
done

# Stop on first error
set -e

# Extract vmlinuz and initrd.img if they are not present
if [ ! -e vmlinuz ] || [ ! -e initrd.img ]; then
    TMPDIR=$(mktemp -d)
    mount -o ro,loop boot.iso ${TMPDIR}
    if [ -e ${TMPDIR}/images/pxeboot/vmlinuz ] && [ -e ${TMPDIR}/images/pxeboot/vmlinuz ]; then
        echo "Copying vmlinuz and initrd.img files from boot.iso..."
        \cp -f ${TMPDIR}/images/pxeboot/vmlinuz .
        \cp -f ${TMPDIR}/images/pxeboot/initrd.img .
        sync
        umount ${TMPDIR}
        \rmdir ${TMPDIR}
    else
        umount ${TMPDIR}
        echo "ERROR: Failed to find vmlinuz and initrd.img files in boot.iso"
        exit 1
    fi
else
    echo "Reusing existing versions of vmlinuz and initrd.img files..."
fi

# Create disk for 8G size
qemu-img create -f raw ${DISKIMGNAME} ${DISKSIZEGB}G

# Create space for UEFI variables
qemu-img create -f raw UEFI_VARS.fd 64M

# Create OEMDRV.iso with volume label OEMDRV and with
# kickstart file copied there as ks.cfg. The boot image looks for
# the file ks.cfg to take kickstart configuration for automated
# installations
echo "Creating isofs for passing kickstart configuration to qemu..."
mkdir -m 755 ksisofs
\cp -f ks-efidisk-centos7.ks ksisofs/ks.cfg
mkisofs -input-charset default -V OEMDRV -o OEMDRV.iso ksisofs

# Apply the following changes to boot into the rescue mode:
#  - Replace "-V OEMDRV" in mkisofs command above to "-V TESTDRV"
#  - In the 'append' arguments, add the following arguments: 
#    . "rescue root=LABEL=CentOS\x207\x20aarch64 ro" 
#    . Retain the original arguments

# Now launch kickstart 
/root/git-qemu-v4.2.1/qemu/aarch64-softmmu/qemu-system-aarch64 \
    -nographic \
    -cpu cortex-a53 -M virt \
    -smp 4 \
    -m 4096 \
    -no-reboot \
    -boot d \
    -drive file=${OVMFPATH},if=pflash,format=raw,unit=0,readonly=on \
    -drive file=UEFI_VARS.fd,if=pflash,format=raw,unit=1 \
    -cdrom boot.iso \
    -drive file=OEMDRV.iso,format=raw,media=cdrom \
    -drive file=${DISKIMGNAME},format=raw,media=disk \
    -kernel vmlinuz \
    -initrd initrd.img \
    -append "inst.stage2=hd:LABEL=CentOS\x207\x20aarch64 console=ttyAMA0,115200n8 inst.text inst.cmdline" \


