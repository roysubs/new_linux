#!/bin/bash

# Update the package lists and install NFS server components
# nfs-common contains showmount etc
sudo apt update
sudo apt install -y nfs-kernel-server nfs-common

# Ensure the NFS server is enabled and running
sudo systemctl enable nfs-server
sudo systemctl start nfs-server

# Define the directory to be shared (here, ~ refers to the home directory)
SHARE_DIR="$HOME"

# Create a backup of the /etc/exports file if it doesn't exist
if [ -f /etc/exports ]; then
    sudo cp "/etc/exports" "/etc/exports.$(date +'%Y-%m-%d_%H-%M-%S').bak"
else
    sudo touch /etc/exports
fi

# Add an entry for the home directory to be shared via NFS (replace with your network)
echo "$SHARE_DIR *(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
echo "rw: Clients can both read and write files within /home/boss."
echo "sync: All changes made by the clients are written to disk immediately for data safety."
echo "no_subtree_check: The server skips additional checks for subtree boundaries, ensuring faster and more reliable access."

# Apply the changes to the NFS exports
sudo exportfs -ra

# Allow NFS through the firewall (if UFW is enabled)
sudo ufw allow from any to any port nfs
sudo ufw reload

# Show the NFS shares
sudo exportfs -v

echo "NFS server setup completed. Home directory '$HOME' is now shared."


# sudo mount.nfs -h
# usage: mount.nfs remotetarget dir [-rvVwfnsh] [-o nfsoptions]
# options:
#         -r              Mount file system readonly
#         -v              Verbose
#         -V              Print version
#         -w              Mount file system read-write
#         -f              Fake mount, do not actually mount
#         -n              Do not update /etc/mtab
#         -s              Tolerate sloppy mount options rather than fail
#         -h              Print this help
#         nfsoptions      Refer to mount.nfs(8) or nfs(5)


# sudo mount -h
# Usage:
#  mount [-lhV]
#  mount -a [options]
#  mount [options] [--source] <source> | [--target] <directory>
#  mount [options] <source> <directory>
#  mount <operation> <mountpoint> [<target>]
# 
# Mount a filesystem.
# 
# Options:
#  -a, --all               mount all filesystems mentioned in fstab
#  -c, --no-canonicalize   don't canonicalize paths
#  -f, --fake              dry run; skip the mount(2) syscall
#  -F, --fork              fork off for each device (use with -a)
#  -T, --fstab <path>      alternative file to /etc/fstab
#  -i, --internal-only     don't call the mount.<type> helpers
#  -l, --show-labels       show also filesystem labels
#  -m, --mkdir[=<mode>]    alias to '-o X-mount.mkdir[=<mode>]'
#  -n, --no-mtab           don't write to /etc/mtab
#      --options-mode <mode>
#                          what to do with options loaded from fstab
#      --options-source <source>
#                          mount options source
#      --options-source-force
#                          force use of options from fstab/mtab
#  -o, --options <list>    comma-separated list of mount options
#  -O, --test-opts <list>  limit the set of filesystems (use with -a)
#  -r, --read-only         mount the filesystem read-only (same as -o ro)
#  -t, --types <list>      limit the set of filesystem types
#      --source <src>      explicitly specifies source (path, label, uuid)
#      --target <target>   explicitly specifies mountpoint
#      --target-prefix <path>
#                          specifies path used for all mountpoints
#  -v, --verbose           say what is being done
#  -w, --rw, --read-write  mount the filesystem read-write (default)
#  -N, --namespace <ns>    perform mount in another namespace
# 
#  -h, --help              display this help
#  -V, --version           display version
# 
# Source:
#  -L, --label <label>     synonym for LABEL=<label>
#  -U, --uuid <uuid>       synonym for UUID=<uuid>
#  LABEL=<label>           specifies device by filesystem label
#  UUID=<uuid>             specifies device by filesystem UUID
#  PARTLABEL=<label>       specifies device by partition label
#  PARTUUID=<uuid>         specifies device by partition UUID
#  ID=<id>                 specifies device by udev hardware ID
#  <device>                specifies device by path
#  <directory>             mountpoint for bind mounts (see --bind/rbind)
#  <file>                  regular file for loopdev setup
# 
# Operations:
#  -B, --bind              mount a subtree somewhere else (same as -o bind)
#  -M, --move              move a subtree to some other place
#  -R, --rbind             mount a subtree and all submounts somewhere else
#  --make-shared           mark a subtree as shared
#  --make-slave            mark a subtree as slave
#  --make-private          mark a subtree as private
#  --make-unbindable       mark a subtree as unbindable
#  --make-rshared          recursively mark a whole subtree as shared
#  --make-rslave           recursively mark a whole subtree as slave
#  --make-rprivate         recursively mark a whole subtree as private
#  --make-runbindable      recursively mark a whole subtree as unbindable
# 
# For more details see mount(8).


# Use find to see nfs executables
# boss@hp2:~/new_linux$ find /{bin,sbin,usr/bin,usr/sbin} -type f -name "*nfs*"
# /usr/sbin/nfsidmap
# /usr/sbin/nfsiostat
# /usr/sbin/nfsdcltrack
# /usr/sbin/nfsdcld
# /usr/sbin/nfsdclnts
# /usr/sbin/nfsstat
# /usr/sbin/nfsconf
# /usr/sbin/rpc.nfsd
# /usr/sbin/mount.nfs
# /usr/sbin/nfsdclddb


# boss@hp2:~$ apropos nfs
# blkmapd (8)          - pNFS block layout mapping daemon
# exportfs (8)         - maintain table of exported NFS file systems
# exports (5)          - NFS server export table
# filesystems (5)      - Linux filesystem types: ext, ext2, ext3, ext4, hpfs, msdos, nfs, ntfs,...
# fs (5)               - Linux filesystem types: ext, ext2, ext3, ext4, hpfs, msdos, nfs, ntfs,...
# idmapd (8)           - NFSv4 ID <-> Name Mapper
# idmapd.conf (5)      - configuration file for libnfsidmap
# mount.nfs (8)        - mount a Network File System
# mountd (8)           - NFS mount daemon
# mountstats (8)       - Displays various NFS client per-mount statistics
# nfs (5)              - fstab format and options for the nfs file systems
# nfs.conf (5)         - general configuration for NFS daemons and tools
# nfs.systemd (7)      - managing NFS services through systemd.
# nfs4_uid_to_name (3) - ID mapping routines used for NFSv4
# nfsconf (8)          - Query various NFS configuration settings
# nfsd (7)             - special filesystem for controlling Linux NFS server
# nfsd (8)             - NFS server process
# nfsdcld (8)          - NFSv4 Client Tracking Daemon
# nfsdclddb (8)        - Tool for manipulating the nfsdcld sqlite database
# nfsdclnts (8)        - print various nfs client information for knfsd server.
# nfsdcltrack (8)      - NFSv4 Client Tracking Callout Program
# nfsidmap (8)         - The NFS idmapper upcall program
# nfsiostat (8)        - Emulate iostat for NFS mount points using /proc/self/mountstats
# nfsmount.conf (5)    - Configuration file for NFS mounts
# nfsrahead (5)        - Configure the readahead for NFS mounts
# nfsservctl (2)       - syscall interface to kernel nfs daemon
# nfsstat (8)          - list NFS statistics
# rpc.idmapd (8)       - NFSv4 ID <-> Name Mapper
# rpc.mountd (8)       - NFS mount daemon
# rpc.nfsd (8)         - NFS server process
# rpc.sm-notify (8)    - send reboot notifications to NFS peers
# rpcdebug (8)         - set and clear NFS and RPC kernel debug flags
# showmount (8)        - show mount information for an NFS server
# sm-notify (8)        - send reboot notifications to NFS peers
# umount.nfs (8)       - unmount a Network File System
# vfs_nfs4acl_xattr (8) - Save NTFS-ACLs as NFS4 encoded blobs in extended attributes
