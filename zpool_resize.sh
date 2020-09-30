#! /bin/bash

set -o pipefail
set -o errtrace
set -o nounset
set -o errexit
set -a

standard_storage_disk="/dev/sdd"
mountpoint=$(hostname -f)

for blkdev in $(nvme list | awk '/^\/dev/ { print $1 }'); do
    mapping=$(nvme id-ctrl --raw-binary "${blkdev}" | cut -c3073-3104 | tr -s ' ' | sed 's/ $//g')
    if [[ ${mapping} == ${standard_storage_disk} ]]; then
        echo "comparing disk with partition..."
        if echo $(cat /sys/class/block/nvme1n1/size)-$(cat /sys/class/block/nvme1n1p1/size)|bc > 4096; then
            echo "resizing partition..."
            growpart ${blkdev} 1
            echo "reloading zpool..."
            zpool online -e $(zpool list -H -o name) $(zpool list -v -H -P | tail -1 | awk '{print $1}')
        fi
    fi
done
