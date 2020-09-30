#! /bin/bash

set -o pipefail
set -o errtrace
set -o nounset
set -o errexit
set -a

standard_storage_disk="/dev/sdd"
standard_storage_location="/storage"
mountpoint=$(hostname -f)

if $(zpool import | grep ${mountpoint} &>/dev/null); then
    echo "importing zpool ${mountpoint} ..."
    zpool import -f ${mountpoint}
    zpool upgrade ${mountpoint}
fi
if ! $(zpool list | grep ${mountpoint} &>/dev/null); then
    for blkdev in $(nvme list | awk '/^\/dev/ { print $1 }'); do
        mapping=$(nvme id-ctrl --raw-binary "${blkdev}" | cut -c3073-3104 | tr -s ' ' | sed 's/ $//g')
        if [[ ${mapping} == ${standard_storage_disk} ]]; then
            echo "formating disk..."
            sgdisk -n1:1M:0 -t1:BF01 ${blkdev}
            echo "creating zpool ${mountpoint} to ${mapping} ..."
            zpool create -o ashift=12 -O atime=off -O compression=lz4 -O relatime=on -O normalization=formD -O canmount=off -O xattr=sa ${mountpoint} ${blkdev}p1
        fi
    done
fi

if ! $(zpool status | grep "state: ONLINE" &>/dev/null); then
    echo "zpool not online, manual recovery needed"
    exit
fi

if ! $(zfs list | grep ${mountpoint}/${mountpoint} &>/dev/null); then
    echo "creating zfs ${mountpoint}/${mountpoint} ..."
    zfs create -o acltype=posixacl -o canmount=on -o mountpoint=/${mountpoint} ${mountpoint}/${mountpoint}
fi

echo "symlinking ${standard_storage_location} -> /${mountpoint} ..."
ln -s /${mountpoint} ${standard_storage_location}
