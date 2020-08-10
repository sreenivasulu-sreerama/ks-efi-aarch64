#!/bin/bash
#
# Launch a VM with disk image that is built using ks-efidisk-xxx.sh

# usage
function usage()
{
    echo "Use this script to luanch VM that is built using one of "
    echo "ks-efixxxxxxx.sh scripts locally here."
    echo ""
    echo "Usage:"
    echo "./launch-efidisk.sh [--help|--ovmf-path] <disk-filename>"
    echo "   --help      - Display this information and exit"
    echo "   --ovmf-path - OVMF filepath to use (default:${OVMFPATH})"
    echo ""
    return
}

# Parse arguments and apply settings accordingly
function parse_args()
{
    local OPTS

    OPTS=$(getopt -o h --long help -n 'parse-options' -- "$@")
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
    if [ $# -ne 1 ]; then
        usage
        echo "ERROR: Insufficient/Unexpected arguments"
        exit 1
    fi

    # Extract disk image filename
    DISKIMGNAME="$1"
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

# Disk image file
DISKIMGNAME=""

# Validate and parse arguments
parse_args "$@"

# Exit if OVMFPATH file is not present
if [ ! -e ${OVMFPATH} ]; then
    usage
    echo "ERROR: OVMFPATH file @${OVMFPATH} not found"
    exit 1
fi

# Validate disk image file
if [ ! -e ${DISKIMGNAME} ]; then
    echo "ERROR: Provided disk image ($DISKIMGNAME) not found"
    exit 1
fi

# Now launch a VM with the disk image as input
/root/git-qemu-v4.2.1/qemu/aarch64-softmmu/qemu-system-aarch64 \
    -nographic \
    -cpu cortex-a53 -M virt \
    -smp 4 \
    -m 4096 \
    -no-reboot \
    -boot c \
    -drive file=${OVMFPATH},if=pflash,format=raw,unit=0,readonly=on \
    -drive file=UEFI_VARS.fd,if=pflash,format=raw,unit=1 \
    -drive file=${DISKIMGNAME},format=raw,media=disk \


