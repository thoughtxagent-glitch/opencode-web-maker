# Web Reconnaissance & OSINT Complete Arsenal

> Bxploit Skill Module — Comprehensive recon and OSINT methodology for web targets.
> Covers subdomain enumeration, DNS recon, port scanning, tech fingerprinting, WAF detection, JS analysis, API discovery, source code leaks, Google dorking, search engine intelligence, certificate transparency, Wayback Machine, parameter discovery, hidden path fuzzing, and wordlist selection.

---

## 1. Subdomain Enumeration

### 1.1 Passive Enumeration

```bash
# Subfinder — fast passive subdomain discovery
subfinder -d target.com -all -o subs.txt

# Amass passive mode — pulls from 40+ sources
amass enum -passive -d target.com -o amass_subs.txt

# Assetfinder — quick, lightweight
assetfinder --subs-only target.com | sort -u > assetfinder_subs.txt

# Findomain — certificate transparency + APIs
findomain -t target.com -u findomain_subs.txt

# crt.sh via curl — certificate transparency logs
curl -s "https://crt.sh/?q=%25.target.com&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > crtsh_subs.txt

# SecurityTrails API
curl -s "https://api.securitytrails.com/v1/domain/target.com/subdomains" \
  -H "APIKEY: YOUR_API_KEY" | jq -r '.subdomains[]' | sed "s/$/.target.com/" > st_subs.txt

# Chaos ProjectDiscovery — curated subdomain datasets
chaos -d target.com -o chaos_subs.txt

# RapidDNS
curl -s "https://rapiddns.io/subdomain/target.com?full=1" | grep -oP '[\w.-]+\.target\.com' | sort -u

# HackerTarget
curl -s "https://api.hackertarget.com/hostsearch/?q=target.com" | cut -d, -f1

# VirusTotal API
curl -s "https://www.virustotal.com/vtapi/v2/domain/report?apikey=YOUR_KEY&domain=target.com" \
  | jq -r '.subdomains[]'

# Shodan subdomains
shodan domain target.com | awk '{print $1}' > shodan_subs.txt

# ThreatCrowd
curl -s "https://www.threatcrowd.org/searchApi/v2/domain/report/?domain=target.com" \
  | jq -r '.subdomains[]'
```

### 1.2 Active Enumeration (Brute-force)

```bash
# Puredns — mass DNS resolution with wildcard filtering
puredns bruteforce /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt target.com \
  -r resolvers.txt --wildcard-tests 30 -w resolved.txt

# Shuffledns — wrapper around massdns
shuffledns -d target.com -w /usr/share/seclists/Discovery/DNS/dns-Jhaddix.txt \
  -r resolvers.txt -o shuffledns_out.txt

# Gobuster DNS mode
gobuster dns -d target.com -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -t 50

# DNSx — fast DNS toolkit (resolve, filter, extract)
cat subs.txt | dnsx -silent -a -resp -o dnsx_resolved.txt

# Altdns — subdomain permutation/alteration
altdns -i subs.txt -o altdns_permutations.txt -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
cat altdns_permutations.txt | puredns resolve -r resolvers.txt > altdns_resolved.txt

# Gotator — advanced subdomain permutations
gotator -sub subs.txt -perm /usr/share/seclists/Discovery/DNS/dns-Jhaddix.txt -depth 1 -numbers 3 \
  | puredns resolve -r resolvers.txt > gotator_resolved.txt

# dnsgen — generate subdomain candidates from existing ones
cat subs.txt | dnsgen - | puredns resolve -r resolvers.txt > dnsgen_resolved.txt
```

### 1.3 Consolidation & Validation

```bash
# Merge all sources
cat subs.txt amass_subs.txt assetfinder_subs.txt crtsh_subs.txt | sort -u > all_subs.txt

# Resolve and filter live hosts
cat all_subs.txt | dnsx -silent -a -cname -resp > resolved_subs.txt

# HTTP probing — find live web services
cat resolved_subs.txt | httpx -silent -status-code -title -tech-detect -follow-redirects -o live_hosts.txt

# Screenshot live hosts
cat live_hosts.txt | aquatone -out screenshots/
# or
gowitness file -f live_hosts.txt --screenshot-path screenshots/
```

---

## 2. DNS Reconnaissance

```bash
# Full DNS record enumeration
dig target.com ANY +noall +answer
dig target.com A +short
dig target.com AAAA +short
dig target.com MX +short
dig target.com NS +short
dig target.com TXT +short
dig target.com SOA +short
dig target.com CNAME +short
dig target.com SRV +short

# Reverse DNS lookup
dig -x 1.2.3.4

# DNS zone transfer attempt
dig axfr target.com @ns1.target.com
# Automated
dnsrecon -d target.com -t axfr

# DNSRecon — comprehensive DNS enumeration
dnsrecon -d target.com -t std,brt,srv,axfr -D /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt

# DNSenum
dnsenum --dnsserver 8.8.8.8 --enum -f /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt target.com

# Fierce — DNS bruteforce and zone transfer
fierce --domain target.com --subdomains /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt

# Check for DNSSEC
dig target.com DNSKEY +dnssec +short

# SPF/DMARC/DKIM records (email security posture)
dig target.com TXT +short | grep -i spf
dig _dmarc.target.com TXT +short
dig selector1._domainkey.target.com TXT +short
dig selector2._domainkey.target.com TXT +short

# DNS cache snooping — check if a domain was recently resolved by a DNS server
dig @ns1.target.com target.com A +norecurse

# NSEC walking (DNSSEC zone enumeration)
ldns-walk @ns1.target.com target.com
# or
nsec3walker target.com

# Detect DNS rebinding potential
# Check if TTL is extremely low (< 60s)
dig target.com A | grep -i "ttl"

# Check for dangling CNAME (subdomain takeover candidates)
cat resolved_subs.txt | grep CNAME | while read sub _ cname; do
  host "$cname" | grep -q "NXDOMAIN" && echo "TAKEOVER: $sub -> $cname"
done

# Nuclei subdomain takeover detection
nuclei -l live_hosts.txt -t /root/nuclei-templates/http/takeovers/ -o takeovers.txt
```

---

## 3. Port Scanning

```bash
# Nmap — SYN scan top 1000 ports
sudo nmap -sS -sV -sC -O -T4 -oA nmap_default target.com

# Full TCP port scan (all 65535)
sudo nmap -sS -p- -T4 --min-rate 5000 -oA nmap_full target.com

# UDP scan (top 100)
sudo nmap -sU --top-ports 100 -T4 -oA nmap_udp target.com

# Version + script scan on discovered ports
sudo nmap -sV -sC -p 22,80,443,8080,8443 -oA nmap_targeted target.com

# Nmap vulnerability scan
sudo nmap -sV --script=vuln -p 80,443 target.com

# Nmap HTTP enumeration
sudo nmap -p 80,443 --script http-enum,http-headers,http-methods,http-title,http-server-header target.com

# Masscan — ultra-fast full port scan
sudo masscan -p1-65535 --rate 10000 -oL masscan_out.txt 1.2.3.4/24

# RustScan — fast port discovery + nmap integration
rustscan -a target.com --ulimit 5000 -- -sV -sC -oA rustscan_out

# Naabu — ProjectDiscovery port scanner
naabu -host target.com -top-ports 1000 -silent -o naabu_ports.txt
# Pipe to httpx
naabu -host target.com -p - -silent | httpx -silent -status-code

# Scan specific service ports
sudo nmap -sV -p 21,22,23,25,53,80,110,111,135,139,143,443,445,993,995,1723,3306,3389,5432,5900,6379,8080,8443,9200,27017 target.com

# Detect firewall/IDS evasion
sudo nmap -sS -T2 -f --data-length 24 -D RND:5 target.com  # Fragmented + decoys
sudo nmap -sS --source-port 53 target.com                     # Source port spoofing
```

---

## 4. Technology Fingerprinting

```bash
# Wappalyzer CLI
wappalyzer https://target.com

# WhatWeb — web technology identification
whatweb -a 3 https://target.com
whatweb -a 3 --url-list live_hosts.txt

# Httpx — built-in tech detection
httpx -u https://target.com -tech-detect -status-code -title -server -content-length -follow-redirects

# Webanalyze (Wappalyzer Go port)
webanalyze -host https://target.com -crawl 2

# Nmap HTTP fingerprinting
nmap -sV -p 80,443 --script http-headers,http-server-header,http-generator target.com

# Curl header analysis
curl -sI https://target.com | grep -iE "server|x-powered-by|x-aspnet|x-generator|x-drupal|x-framework|set-cookie"

# Detect CMS
# WordPress
curl -s https://target.com/wp-login.php | head -5
curl -s https://target.com/wp-json/wp/v2/users
wpscan --url https://target.com --enumerate u,p,t,vp,vt --api-token YOUR_TOKEN

# Joomla
curl -s https://target.com/administrator/ | head -5
joomscan -u https://target.com

# Drupal
curl -s https://target.com/CHANGELOG.txt | head -5
droopescan scan drupal -u https://target.com

# Identify JavaScript frameworks from response
curl -s https://target.com | grep -oiE '(react|angular|vue|next|nuxt|svelte|ember|backbone|jquery)["\s/.-][\d.]*' | sort -u

# Detect web server specifics
curl -s -o /dev/null -w "%{http_code}" https://target.com/doesnotexist12345
curl -sI https://target.com -H "Host: invalid" 2>/dev/null | head -20

# Nuclei tech detection
nuclei -u https://target.com -t /root/nuclei-templates/http/technologies/ -silent
```

---

## 5. WAF Detection & Fingerprinting

```bash
# Wafw00f — WAF detection
wafw00f https://target.com
wafw00f -l  # List all detectable WAFs
wafw00f https://target.com -a  # Test all WAF signatures

# Nmap WAF detection
nmap -p 80,443 --script http-waf-detect,http-waf-fingerprint target.com

# Manual WAF detection — trigger a signature and observe response
curl -sI "https://target.com/?id=1' OR 1=1--" | head -20
curl -sI "https://target.com/?q=<script>alert(1)</script>" | head -20
curl -sI "https://target.com/?cmd=../../etc/passwd" | head -20

# Check for common WAF headers
curl -sI https://target.com | grep -iE "cf-ray|x-sucuri|x-cdn|x-akamai|x-cache|x-varnish|server.*cloudflare|server.*akamai|server.*incapsula|x-fw-|x-waf|x-protected"

# Cloudflare real IP discovery
# Check DNS history
curl -s "https://securitytrails.com/domain/target.com/dns" | grep -oP '\d+\.\d+\.\d+\.\d+'
# Censys search for original IP
censys search "services.tls.certificates.leaf.names: target.com" --index-type hosts
# CloudFlair
python3 cloudflair.py target.com
# Check mail server IP (often same server)
dig target.com MX +short
dig mail.target.com A +short

# Bypass WAF via HTTP methods
curl -X TRACE https://target.com/
curl -X OPTIONS https://target.com/

# Identify WAF by error page signatures
# Cloudflare: "Attention Required!" / "Error 1020"
# AWS WAF: "403 Forbidden" with "x-amzn-RequestId"
# Akamai: "Access Denied" / "Reference #"
# Imperva/Incapsula: "Request unsuccessful. Incapsula"
# ModSecurity: "Not Acceptable!" / "ModSecurity"
# F5 BIG-IP ASM: "The requested URL was rejected"

# Nmap NSE for specific WAF identification
nmap -p 443 --script http-waf-detect --script-args="http-waf-detect.detectBodyChanges" target.com
```

---

## 6. JavaScript Analysis & Secrets Extraction

```bash
# Gather all JS files from a target
echo "https://target.com" | gau --threads 5 | grep -iE '\.js$' | sort -u > js_files.txt
echo "https://target.com" | katana -jc -d 3 -silent | grep -iE '\.js$' | sort -u >> js_files.txt
echo "https://target.com" | waybackurls | grep -iE '\.js$' | sort -u >> js_files.txt
sort -u js_files.txt -o js_files.txt

# Download all JS files
mkdir -p js_downloads
while read url; do
  filename=$(echo "$url" | md5sum | cut -d' ' -f1).js
  curl -sk "$url" -o "js_downloads/$filename"
done < js_files.txt

# LinkFinder — extract endpoints from JS
python3 linkfinder.py -i https://target.com -d -o cli

# SecretFinder — find secrets, API keys, tokens in JS
python3 SecretFinder.py -i https://target.com -e -o cli

# Grep for secrets in downloaded JS
grep -rniE "(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|client[_-]?secret|password|passwd|secret|private[_-]?key|aws[_-]?access|firebase|AIza|AKIA|sk-live|sk-test|rk_live|sq0)" js_downloads/

# Grep for URLs and endpoints in JS
grep -rhoP "(https?://[^\s\"'<>]+)" js_downloads/ | sort -u > js_urls.txt
grep -rhoP "(/api/[^\s\"'<>]+)" js_downloads/ | sort -u > js_api_endpoints.txt
grep -rhoP '["'"'"'](/[a-zA-Z0-9_/.-]{3,})["'"'"']' js_downloads/ | sort -u > js_paths.txt

# Look for source maps
grep -rn "sourceMappingURL" js_downloads/
# Download and decompile source maps
curl -sk "https://target.com/static/js/main.chunk.js.map" -o sourcemap.map
# Use shuji or source-map-explorer to reconstruct source
npx shuji sourcemap.map -o reconstructed/

# Nuclei JS exposure checks
nuclei -l js_files.txt -t /root/nuclei-templates/http/exposures/ -silent

# JSFScan — all-in-one JS recon
bash JSFScan.sh -l live_hosts.txt

# Mantra — JS secrets scanner (regex-based)
mantra -url https://target.com -output mantra_secrets.txt

# Trufflehog for JS files
trufflehog filesystem js_downloads/ --json > trufflehog_js.json

# Extract GraphQL schemas from JS
grep -rn "query\|mutation\|subscription\|__schema\|__type\|graphql" js_downloads/
```

---

## 7. API Endpoint Discovery

```bash
# Katana — fast web crawler with JS parsing
katana -u https://target.com -d 5 -jc -kf all -silent -o katana_urls.txt

# GAU — fetch known URLs from AlienVault, Wayback, Common Crawl
gau target.com --threads 5 --o gau_urls.txt

# Waybackurls
echo "target.com" | waybackurls > wayback_urls.txt

# Extract unique API paths
cat katana_urls.txt gau_urls.txt wayback_urls.txt | grep -iE "/api/|/v[0-9]+/|/graphql|/rest/|/json|/xml" | sort -u > api_endpoints.txt

# Fuzz API versions
ffuf -u https://target.com/api/FUZZ -w <(seq 1 20 | sed 's/^/v/') -mc 200,301,302,403

# Common API path brute-force
ffuf -u https://target.com/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt -mc all -fc 404

# Swagger/OpenAPI endpoint discovery
for path in /swagger.json /openapi.json /api-docs /swagger-ui.html /swagger/v1/swagger.json /v2/api-docs /v3/api-docs /.well-known/openapi.yaml /docs /redoc; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$code" != "404" ] && echo "[${code}] https://target.com$path"
done

# GraphQL endpoint discovery
for path in /graphql /graphiql /graphql/console /graphql.php /graphql/graphql /api/graphql /query; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" -X POST "https://target.com$path" \
    -H "Content-Type: application/json" -d '{"query":"{__typename}"}')
  [ "$code" != "404" ] && echo "[${code}] https://target.com$path"
done

# GraphQL introspection
curl -sk -X POST https://target.com/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ __schema { types { name fields { name type { name } } } } }"}'

# Kiterunner — API path brute-force with method detection
kr scan https://target.com -w /path/to/routes-large.kite -x 20 --fail-status-codes 404,400

# Arjun — parameter discovery for APIs
arjun -u https://target.com/api/endpoint -m GET,POST -o arjun_params.json

# FFUF API fuzzing with multiple methods
ffuf -u https://target.com/api/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt \
  -X GET -mc all -fc 404 -H "Content-Type: application/json"
ffuf -u https://target.com/api/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt \
  -X POST -mc all -fc 404 -H "Content-Type: application/json" -d '{}'

# Postman collection/workspace leaks
curl -s "https://www.postman.com/_api/ws/proxy" \
  -H "Content-Type: application/json" \
  -d '{"service":"search","method":"POST","path":"/search-all","body":{"queryIndices":["collaboration.workspace"],"queryText":"target.com"}}'
```

---

## 8. Git / SVN / Source Code Leaks

```bash
# Check for exposed .git directory
curl -sk https://target.com/.git/HEAD
curl -sk https://target.com/.git/config
curl -sk https://target.com/.git/logs/HEAD

# GitTools — dump exposed .git
python3 gitdumper.py https://target.com/.git/ output_dir/
# Reconstruct repository
python3 extractor.py output_dir/ reconstructed_repo/

# git-dumper (alternative)
git-dumper https://target.com/.git/ dumped_repo/

# Check for SVN exposure
curl -sk https://target.com/.svn/entries
curl -sk https://target.com/.svn/wc.db

# SVN extractor
svn-extractor https://target.com/.svn/

# Check for other source leaks
for path in /.git/HEAD /.git/config /.svn/entries /.svn/wc.db /.hg/store /.bzr/README /CVS/Root /.DS_Store /Thumbs.db /.env /.env.bak /.env.old /.env.production /config.php.bak /wp-config.php.bak /web.config /database.yml /settings.py /.npmrc /.dockerenv /docker-compose.yml /Dockerfile /Makefile /.htaccess /.htpasswd /server-status /server-info /composer.json /package.json /Gemfile /requirements.txt /Pipfile; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$code" = "200" ] && echo "[FOUND] https://target.com$path"
done

# GitHub/GitLab dorking for target
# Search GitHub
# "target.com" password
# "target.com" secret
# "target.com" api_key
# org:targetorg filename:.env
# org:targetorg filename:id_rsa
# org:targetorg filename:.npmrc

# Trufflehog — scan repos for secrets
trufflehog github --org targetorg --json > trufflehog_github.json
trufflehog git https://github.com/target/repo.git --json > trufflehog_repo.json

# GitLeaks
gitleaks detect -s /path/to/repo --report-path gitleaks_report.json

# Gitrob (for GitHub orgs)
gitrob -o target_org

# Check for backup/swap files
for ext in .bak .old .orig .save .swp .swo ~ .tmp .copy .1 .2 .backup; do
  for file in index.php config.php login.php admin.php database.php settings.php; do
    code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com/${file}${ext}")
    [ "$code" = "200" ] && echo "[FOUND] https://target.com/${file}${ext}"
  done
done

# Check for IDE/editor artifacts
for path in /.idea/workspace.xml /.vscode/settings.json /.project /.classpath /nbproject/project.xml /.editorconfig; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$code" = "200" ] && echo "[FOUND] https://target.com$path"
done
```

---

## 9. Google Dorking

```bash
# Subdomain discovery
# site:target.com -www

# Login/admin pages
# site:target.com inurl:admin
# site:target.com inurl:login
# site:target.com intitle:"admin panel"
# site:target.com inurl:dashboard

# Sensitive files
# site:target.com filetype:pdf
# site:target.com filetype:xlsx OR filetype:csv
# site:target.com filetype:doc OR filetype:docx
# site:target.com filetype:sql
# site:target.com filetype:log
# site:target.com filetype:env
# site:target.com filetype:xml
# site:target.com filetype:conf OR filetype:cfg
# site:target.com filetype:bak OR filetype:old

# Exposed directories
# site:target.com intitle:"Index of /"
# site:target.com intitle:"Directory listing"

# Credentials and secrets
# site:target.com intext:password filetype:log
# site:target.com intext:"db_password" filetype:php
# site:target.com inurl:".env" intext:"DB_PASSWORD"
# "target.com" intext:api_key
# "target.com" intext:secret_key

# Error messages (information disclosure)
# site:target.com intext:"SQL syntax" | intext:"mysql_fetch" | intext:"Warning: pg_"
# site:target.com intext:"Fatal error" | intext:"Stack trace"
# site:target.com intext:"Parse error" filetype:php
# site:target.com intitle:"phpinfo()"

# Specific technology exposure
# site:target.com inurl:wp-content
# site:target.com inurl:wp-admin
# site:target.com inurl:xmlrpc.php
# site:target.com inurl:jmx-console
# site:target.com inurl:server-status
# site:target.com inurl:server-info
# site:target.com inurl:.git
# site:target.com inurl:phpmyadmin

# Cloud storage leaks
# site:s3.amazonaws.com "target"
# site:blob.core.windows.net "target"
# site:storage.googleapis.com "target"
# site:digitaloceanspaces.com "target"

# API documentation exposure
# site:target.com inurl:api-docs | inurl:swagger | inurl:openapi | inurl:graphql

# Paste sites
# site:pastebin.com "target.com"
# site:paste.ee "target.com"
# site:hastebin.com "target.com"
# site:ghostbin.co "target.com"

# Automated Google dorking
# pagodo — automates Google hacking
pagodo -d target.com -g /path/to/dorks.txt -l 100 -s -e 35.0 -j 1.1

# Dorkscout
dorkscout -t target.com -d /path/to/dorks.txt
```

---

## 10. Shodan / Censys / FOFA / ZoomEye

### 10.1 Shodan

```bash
# CLI searches
shodan search "hostname:target.com" --fields ip_str,port,org,os,product
shodan host 1.2.3.4
shodan domain target.com
shodan stats --facets port hostname:target.com
shodan count "ssl.cert.subject.CN:target.com"

# Useful Shodan dorks
# hostname:"target.com"
# ssl:"target.com"
# ssl.cert.subject.CN:"target.com"
# org:"Target Organization"
# http.title:"target"
# http.html:"target.com"
# http.favicon.hash:HASH_VALUE   (use https://github.com/Viralmaniar/Passhunt for favicon hash)
# port:9200 hostname:target.com   (Elasticsearch)
# port:27017 hostname:target.com  (MongoDB)
# port:6379 hostname:target.com   (Redis)

# Shodan favicon hash search (find related infrastructure)
python3 -c "
import mmh3, requests, codecs
r = requests.get('https://target.com/favicon.ico', verify=False)
favicon = codecs.encode(r.content, 'base64')
print(f'http.favicon.hash:{mmh3.hash(favicon)}')
"
```

### 10.2 Censys

```bash
# Censys CLI
censys search "services.tls.certificates.leaf.names: target.com" --index-type hosts
censys search "services.http.response.html_title: target" --index-type hosts
censys view 1.2.3.4 --index-type hosts

# Censys subdomain enumeration
censys subdomains target.com

# Useful Censys queries
# services.tls.certificates.leaf.names: target.com
# services.http.response.headers.server: nginx AND services.tls.certificates.leaf.names: target.com
# autonomous_system.name: "Target ISP" AND services.port: 443
```

### 10.3 FOFA

```bash
# FOFA queries (via web or API)
# domain="target.com"
# host="target.com"
# cert="target.com"
# icon_hash="FAVICON_HASH"
# body="target.com"
# title="target"
# header="target.com"
# server="nginx" && domain="target.com"
# port="8443" && domain="target.com"

# FOFA API
curl "https://fofa.info/api/v1/search/all?email=YOUR_EMAIL&key=YOUR_KEY&qbase64=$(echo -n 'domain="target.com"' | base64)&size=100"
```

### 10.4 ZoomEye

```bash
# ZoomEye queries
# hostname:target.com
# site:target.com
# ssl:"target.com"
# app:"Apache" hostname:target.com

# ZoomEye CLI
zoomeye search "hostname:target.com" -num 100 -type host
```

---

## 11. Certificate Transparency

```bash
# crt.sh — primary CT log search
curl -s "https://crt.sh/?q=%25.target.com&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u

# crt.sh with Organization search
curl -s "https://crt.sh/?O=Target+Organization&output=json" | jq -r '.[].name_value' | sort -u

# Certspotter
curl -s "https://api.certspotter.com/v1/issuances?domain=target.com&include_subdomains=true&expand=dns_names" \
  | jq -r '.[].dns_names[]' | sort -u

# Google Transparency Report
curl -s "https://transparencyreport.google.com/transparencyreport/api/v3/httpsreport/ct/certsearch?include_expired=true&include_subdomains=true&domain=target.com"

# Facebook CT monitor
curl -s "https://graph.facebook.com/certificates?query=target.com&access_token=YOUR_TOKEN" | jq

# Certsh tool (batch queries)
certsh -d target.com -o ct_subs.txt

# CT log monitoring (continuous)
# sublert — monitors CT logs for new subdomains
python3 sublert.py -u target.com

# Ctfr
python3 ctfr.py -d target.com -o ctfr_subs.txt

# Extract certificate info with OpenSSL
echo | openssl s_client -connect target.com:443 -servername target.com 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
echo | openssl s_client -connect target.com:443 -servername target.com 2>/dev/null | openssl x509 -noout -dates -issuer -subject
```

---

## 12. Wayback Machine & Historical Data

```bash
# Waybackurls — fetch historical URLs
echo "target.com" | waybackurls > wayback_all.txt

# GAU (GetAllUrls) — Wayback + Common Crawl + AlienVault + URLScan
gau target.com --threads 5 --o gau_all.txt

# Waymore — enhanced Wayback fetcher
python3 waymore.py -i target.com -mode U -oU waymore_urls.txt

# Filter for interesting files
cat wayback_all.txt | grep -iE "\.(php|asp|aspx|jsp|json|xml|config|conf|env|sql|bak|old|log|txt|yml|yaml|ini|db|sqlite|zip|tar|gz|rar)(\?|$)" | sort -u > wayback_interesting.txt

# Filter for parameters (potential injection points)
cat wayback_all.txt | grep "=" | sort -u > wayback_params.txt

# Filter for API endpoints
cat wayback_all.txt | grep -iE "/api/|/v[0-9]+/|/rest/|/graphql" | sort -u > wayback_api.txt

# Check for old/removed pages still accessible
cat wayback_interesting.txt | httpx -silent -status-code -mc 200 > wayback_live.txt

# Wayback Machine direct snapshot access
curl -s "https://web.archive.org/web/2020*/https://target.com/robots.txt"
curl -s "https://web.archive.org/web/2020*/https://target.com/sitemap.xml"
curl -s "https://web.archive.org/web/2020*/https://target.com/.env"

# Wayback CDX API — structured URL listing
curl -s "http://web.archive.org/cdx/search/cdx?url=*.target.com/*&output=json&fl=original&collapse=urlkey" | jq -r '.[][]' | sort -u

# Common Crawl index search
python3 -c "
import requests
index = 'CC-MAIN-2024-10'
url = f'https://index.commoncrawl.org/{index}-index?url=*.target.com&output=json'
r = requests.get(url)
for line in r.text.strip().split('\n'):
    import json
    data = json.loads(line)
    print(data.get('url'))
"

# URLScan.io
curl -s "https://urlscan.io/api/v1/search/?q=domain:target.com" | jq -r '.results[].page.url'
```

---

## 13. Parameter Discovery

```bash
# Arjun — automated parameter discovery
arjun -u https://target.com/endpoint -m GET -o arjun_get.json
arjun -u https://target.com/endpoint -m POST -o arjun_post.json
arjun -u https://target.com/endpoint -m JSON -o arjun_json.json

# ParamSpider — mine parameters from web archives
python3 paramspider.py -d target.com -o paramspider_out.txt

# x8 — hidden parameter discovery
x8 -u https://target.com/endpoint -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt

# Mine parameters from collected URLs
cat wayback_all.txt gau_all.txt | unfurl keys | sort | uniq -c | sort -rn > param_frequency.txt

# FFUF parameter fuzzing
ffuf -u "https://target.com/endpoint?FUZZ=test" \
  -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt \
  -mc all -fc 404 -fs BASELINE_SIZE

# POST parameter fuzzing
ffuf -u "https://target.com/endpoint" -X POST \
  -d "FUZZ=test" \
  -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -mc all -fc 404 -fs BASELINE_SIZE

# JSON parameter fuzzing
ffuf -u "https://target.com/api/endpoint" -X POST \
  -d '{"FUZZ":"test"}' \
  -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt \
  -H "Content-Type: application/json" \
  -mc all -fc 404 -fs BASELINE_SIZE

# Header fuzzing
ffuf -u https://target.com/ \
  -w /usr/share/seclists/Discovery/Web-Content/BurpSuite-ParamMiner/lowercase-headers.txt \
  -H "FUZZ: 127.0.0.1" -mc all -fc 404 -fs BASELINE_SIZE

# Common hidden/debug parameters to test manually
# ?debug=true  ?debug=1  ?test=true  ?admin=true
# ?source=true  ?view=source  ?format=json
# X-Custom-IP-Authorization: 127.0.0.1
# X-Original-URL: /admin
# X-Rewrite-URL: /admin
# X-Forwarded-For: 127.0.0.1
# X-Forwarded-Host: 127.0.0.1
```

---

## 14. Hidden Path Fuzzing & Directory Brute-Force

```bash
# FFUF — fast web fuzzer
ffuf -u https://target.com/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt \
  -mc all -fc 404 -t 100 -recursion -recursion-depth 2 -o ffuf_dirs.json

# FFUF with extension fuzzing
ffuf -u https://target.com/FUZZ \
  -w /usr/share/seclists/Discovery/Web-Content/raft-large-words.txt \
  -e .php,.asp,.aspx,.jsp,.html,.js,.json,.xml,.txt,.bak,.old,.conf,.cfg,.ini,.log,.sql,.zip,.tar.gz \
  -mc all -fc 404 -t 80

# Feroxbuster — recursive content discovery
feroxbuster -u https://target.com -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt \
  -x php,html,js,txt,json -d 3 -t 100 --smart -o feroxbuster_out.txt

# Gobuster
gobuster dir -u https://target.com -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt \
  -x php,html,txt,bak,json -t 50 -o gobuster_out.txt

# Dirsearch
dirsearch -u https://target.com -e php,asp,aspx,jsp,html,js,json,xml,txt -t 50 --deep-recursive

# Dirb
dirb https://target.com /usr/share/seclists/Discovery/Web-Content/common.txt -o dirb_out.txt

# IIS-specific fuzzing (short filename disclosure)
python3 iis_shortname_scanner.py https://target.com/
# or
java -jar IIS-ShortName-Scanner.jar https://target.com/

# Technology-specific paths
# Spring Boot Actuator
for path in /actuator /actuator/health /actuator/env /actuator/beans /actuator/mappings /actuator/configprops /actuator/heapdump /actuator/threaddump /actuator/loggers /actuator/metrics /actuator/trace /actuator/httptrace /actuator/info /actuator/scheduledtasks /actuator/conditions /jolokia /jolokia/list; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$code" != "404" ] && echo "[${code}] https://target.com$path"
done

# Laravel-specific
for path in /telescope /horizon /nova /log-viewer /_debugbar /storage/logs/laravel.log /debug/default/view /.env.backup; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$code" != "404" ] && echo "[${code}] https://target.com$path"
done

# Django-specific
for path in /admin/ /debug/ /__debug__/ /api/schema/ /api/docs/ /silk/ /static/admin/; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$code" != "404" ] && echo "[${code}] https://target.com$path"
done

# Node.js-specific
for path in /console /debug /status /metrics /healthcheck /graphql /playground /socket.io/ /webpack.config.js /package.json /.npmrc /node_modules/ /npm-debug.log; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com$path")
  [ "$code" != "404" ] && echo "[${code}] https://target.com$path"
done

# Virtual host fuzzing
ffuf -u https://target.com/ -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt \
  -H "Host: FUZZ.target.com" -mc all -fc 404 -fs BASELINE_SIZE

# 403 bypass techniques
# Try path variations
for bypass in "/admin" "/Admin" "/ADMIN" "//admin" "/./admin" "/admin/" "/admin/." "/%2f/admin" "/admin%20" "/admin%09" "/admin..;/" "/;/admin" "/.;/admin" "/admin;/" "/admin../" "/admin../"; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" "https://target.com$bypass")
  echo "[${code}] $bypass"
done
```

---

## 15. Wordlists & Resources

### 15.1 Essential Wordlists

| Purpose | Path |
|---------|------|
| Subdomain brute | `/usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt` |
| Subdomain comprehensive | `/usr/share/seclists/Discovery/DNS/dns-Jhaddix.txt` |
| Directory medium | `/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt` |
| Directory large | `/usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt` |
| Files large | `/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt` |
| Words large | `/usr/share/seclists/Discovery/Web-Content/raft-large-words.txt` |
| Common files | `/usr/share/seclists/Discovery/Web-Content/common.txt` |
| API endpoints | `/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt` |
| Parameters | `/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt` |
| CGI scripts | `/usr/share/seclists/Discovery/Web-Content/CGIs.txt` |
| Spring Boot | `/usr/share/seclists/Discovery/Web-Content/spring-boot.txt` |
| Sensitive paths | `/usr/share/seclists/Discovery/Web-Content/quickhits.txt` |
| IIS paths | `/usr/share/seclists/Discovery/Web-Content/IIS.fuzz.txt` |
| Nginx paths | `/usr/share/seclists/Discovery/Web-Content/nginx.txt` |
| Tomcat paths | `/usr/share/seclists/Discovery/Web-Content/tomcat.txt` |
| Technology detect | `/usr/share/seclists/Discovery/Web-Content/tech-detect-body.txt` |

### 15.2 Custom Wordlist Generation

```bash
# CeWL — custom wordlist from target website
cewl https://target.com -d 3 -m 5 -w cewl_wordlist.txt

# Generate wordlists from JS files
cat js_downloads/*.js | grep -oP '[a-zA-Z_][a-zA-Z0-9_]{2,30}' | sort -u > js_words.txt

# Generate wordlists from collected URLs
cat wayback_all.txt | unfurl paths | tr '/' '\n' | sort -u > path_words.txt

# Combine and deduplicate
cat /usr/share/seclists/Discovery/Web-Content/raft-large-words.txt js_words.txt path_words.txt cewl_wordlist.txt | sort -u > combined_wordlist.txt

# Generate permutations from known patterns
# If target uses /api/v1/users, /api/v1/orders
# Generate: /api/v2/users, /api/v1/accounts, /internal/v1/users, etc.

# Username wordlist
/usr/share/seclists/Usernames/Names/names.txt
/usr/share/seclists/Usernames/cirt-default-usernames.txt

# Password wordlist
/usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt
/usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt
```

### 15.3 DNS Resolvers

```bash
# Reliable public DNS resolvers for mass resolution
cat > resolvers.txt << 'EOF'
8.8.8.8
8.8.4.4
1.1.1.1
1.0.0.1
9.9.9.9
149.112.112.112
208.67.222.222
208.67.220.220
64.6.64.6
64.6.65.6
77.88.8.8
77.88.8.1
EOF

# Validate resolvers
dnsvalidator -tL https://public-dns.info/nameservers.txt -threads 100 -o valid_resolvers.txt
```

---

## 16. Automated Recon Pipelines

### 16.1 Quick Recon One-Liner

```bash
# Discover → Resolve → Probe → Screenshot
subfinder -d target.com -silent | dnsx -silent | httpx -silent -status-code -title -tech-detect | tee live_targets.txt
```

### 16.2 Full Recon Pipeline

```bash
#!/bin/bash
TARGET="target.com"
OUT="recon_${TARGET}"
mkdir -p "$OUT"

echo "[*] Phase 1: Subdomain Enumeration"
subfinder -d $TARGET -all -silent > "$OUT/subs_subfinder.txt"
amass enum -passive -d $TARGET -o "$OUT/subs_amass.txt" 2>/dev/null
assetfinder --subs-only $TARGET > "$OUT/subs_assetfinder.txt"
curl -s "https://crt.sh/?q=%25.$TARGET&output=json" | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' > "$OUT/subs_crt.txt"
cat "$OUT"/subs_*.txt | sort -u > "$OUT/all_subs.txt"
echo "[+] Found $(wc -l < "$OUT/all_subs.txt") unique subdomains"

echo "[*] Phase 2: DNS Resolution"
cat "$OUT/all_subs.txt" | dnsx -silent -a -resp > "$OUT/resolved.txt"
echo "[+] Resolved $(wc -l < "$OUT/resolved.txt") subdomains"

echo "[*] Phase 3: HTTP Probing"
cat "$OUT/resolved.txt" | httpx -silent -status-code -title -tech-detect -follow-redirects > "$OUT/live_hosts.txt"
echo "[+] Found $(wc -l < "$OUT/live_hosts.txt") live web services"

echo "[*] Phase 4: Port Scanning"
cat "$OUT/resolved.txt" | cut -d' ' -f1 | naabu -top-ports 1000 -silent > "$OUT/open_ports.txt"
echo "[+] Found $(wc -l < "$OUT/open_ports.txt") open ports"

echo "[*] Phase 5: URL Collection"
cat "$OUT/all_subs.txt" | waybackurls > "$OUT/wayback_urls.txt"
cat "$OUT/all_subs.txt" | while read sub; do gau "$sub" 2>/dev/null; done > "$OUT/gau_urls.txt"
cat "$OUT"/wayback_urls.txt "$OUT"/gau_urls.txt | sort -u > "$OUT/all_urls.txt"
echo "[+] Collected $(wc -l < "$OUT/all_urls.txt") unique URLs"

echo "[*] Phase 6: JS Analysis"
cat "$OUT/all_urls.txt" | grep -iE '\.js$' | sort -u > "$OUT/js_files.txt"
echo "[+] Found $(wc -l < "$OUT/js_files.txt") JS files"

echo "[*] Phase 7: Nuclei Scanning"
nuclei -l "$OUT/live_hosts.txt" -t /root/nuclei-templates/ -severity low,medium,high,critical -silent -o "$OUT/nuclei_results.txt"
echo "[+] Nuclei found $(wc -l < "$OUT/nuclei_results.txt") issues"

echo "[*] Recon complete. Results in $OUT/"
```

### 16.3 Popular Recon Frameworks

```bash
# ReconFTW — full automated recon
reconftw -d target.com -a -o reconftw_output/

# LazyRecon
bash lazyrecon.sh -d target.com

# Osmedeus — next-gen recon engine
osmedeus scan -t target.com -f general

# AutoRecon (network-focused)
autorecon target.com
```

---

## 17. OSINT — People & Organization

```bash
# theHarvester — email and subdomain harvesting
theHarvester -d target.com -l 500 -b all

# SpiderFoot — automated OSINT
spiderfoot -s target.com -t all

# Maltego — visual OSINT (GUI)
# Transform: Domain → DNS Names, Emails, Subdomains, Technologies

# Email enumeration
curl -s "https://api.hunter.io/v2/domain-search?domain=target.com&api_key=YOUR_KEY" | jq '.data.emails[].value'

# LinkedIn enumeration (manual)
# site:linkedin.com "target company"
# site:linkedin.com/in "target.com"

# Social media OSINT
sherlock username
maigret username

# Breach data lookup
# haveibeenpwned.com API
curl -s "https://haveibeenpwned.com/api/v3/breachedaccount/user@target.com" \
  -H "hibp-api-key: YOUR_KEY" -H "user-agent: bxploit"

# Dehashed (requires API key)
curl -s "https://api.dehashed.com/search?query=domain:target.com" \
  -H "Accept: application/json" -u "email:api_key"
```

---

## Disclaimer

This skill module is for **authorized penetration testing and educational purposes only**. Always ensure you have proper written authorization before performing any reconnaissance or scanning activities against a target. Unauthorized access to computer systems is illegal.
