# auto-partition-mount-share.sh

Automates disk provisioning on Linux: partitioning, formatting, mounting, and optional NFS/Samba sharing.

---

## 🔧 Features

* Creates a new **aligned** partition using available free space
* Supports optional size (e.g., `5G`, `100M`, `1T`)
* Formats as **ext4**
* Mounts under `/mnt/<partition_name>`
* Adds entry to `/etc/fstab`
* Optionally creates:

  * **NFS export** in `/etc/exports` (if `exportfs` is available)
  * **Samba share** in `/etc/samba/smb.conf` (if `smbclient` is available)

---

## 🚀 Usage

```bash
sudo ./auto-partition-mount-share.sh /dev/sdX [SIZE]
```

### Arguments

| Argument   | Description                                                  |
| ---------- | ------------------------------------------------------------ |
| `/dev/sdX` | Target disk (e.g. `/dev/sdb`)                                |
| `SIZE`     | Optional size (e.g. `5G`, `100M`, `1T`). Uses max if omitted |

---

## 💡 Example

Create a 10GB ext4 partition on `/dev/sdb`:

```bash
sudo ./auto-partition-mount-share.sh /dev/sdb 10G
```

This will:

* Create a partition aligned on sector boundaries
* Format it as ext4
* Mount it to `/mnt/sdb1`
* Add it to `/etc/fstab`
* Share via NFS and/or Samba if supported

---

## ⚠️ Warnings

* **Do not run on mounted/system disks** (e.g. `/dev/sda`)
* Assumes **GPT** disk label. Creates one if not present.
* All operations are **idempotent**—existing shares or fstab lines are reused.
* Always **verify disk names with `lsblk`** before use.

---

## 🧰 Requirements

* `bash`
* `parted`
* `mkfs.ext4`
* `mount`
* `lsblk`
* `blockdev`
* Optional:

  * `exportfs` (for NFS)
  * `smbclient`, `systemctl` (for Samba)

---

## 📝 Sample Output

```
Running: lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,UUID,MOUNTPOINTS
NAME   MAJ:MIN RM  SIZE RO TYPE UUID                                 MOUNTPOINTS
sdb      8:16   0   10G  0 disk
└─sdb1   8:17   0   10G  0 part 12abc3f4-5678-90ab-cdef-1234567890ab  /mnt/sdb1

Partition sdb1 successfully formatted and mounted.
NFS share exported.
Samba share added to /etc/samba/smb.conf.
```

---

## 📂 Directory & File Example

| File                            | Purpose                       |
| ------------------------------- | ----------------------------- |
| `auto-partition-mount-share.sh` | Main script                   |
| `/mnt/sdb1`                     | Mount point for new partition |
| `/etc/fstab`                    | Mount persists after reboot   |
| `/etc/exports`                  | NFS share definition          |
| `/etc/samba/smb.conf`           | Samba share definition        |

---

## 📌 License

MIT — Use freely, but test responsibly.

