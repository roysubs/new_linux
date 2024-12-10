#!/bin/bash

# Finding All Disks:
# lsblk -o NAME,SIZE,TYPE,MOUNTPOINT: Lists block devices.
# lsblk -d -n -o NAME : get all block devices (disks) without partitions. Generate a report for each disk.
# lsblk /dev/disk: Detailed information about the specific disk.
# smartctl -a /dev/disk: Provides a SMART status report for the disk.
# nvme smart-log /dev/disk: Shows NVMe disk statistics (only for NVMe drives).
# hdparm -I /dev/disk: Provides detailed information about the disk.
# The results of each command are written to the report file, prefixed with the command that was run.

