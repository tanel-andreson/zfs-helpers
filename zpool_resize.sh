#! /bin/bash

set -o pipefail
set -o errtrace
set -o nounset
set -o errexit
set -a

zfs_partition=$(zpool list -v  | tail -1 | awk '{print $1}')
zfs_disk=$(zpool list -v  | tail -1 | awk '{print $1}' | cut -c1-7)
partition_size=$(cat /sys/class/block/"$zfs_partition"/size)
disk_size=$(cat /sys/class/block/"$zfs_disk"/size)
disk_diff=$((disk_size - partition_size))

echo "comparing disk with partition..."
if (("$disk_diff" > 4096)) ; then
    echo "sleeping for 30 seconds to allow aws to finish optimizing...."
    sleep 30
    echo "resizing partition..."
    growpart /dev/${zfs_disk} 1
    echo "reloading zpool..."
    zpool online -e $(zpool list -H -o name) $(zpool list -v -H -P | tail -1 | awk '{print $1}')
    echo "done."
else
    echo "no changes needed."
fi
