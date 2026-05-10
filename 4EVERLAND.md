# 4EVERLAND & IPFS - Lab 18

## Overview

This lab prepares the course landing page for decentralized hosting with IPFS and 4EVERLAND.

IPFS uses content addressing: the content itself produces the identifier. If the file changes, the CID changes. 4EVERLAND adds a practical dashboard for hosting, storage buckets, pinning, gateways, and stable project URLs.

## Static Site

Prepared site:

```text
labs/lab18/index.html
```

4EVERLAND Hosting settings:

| Setting | Value |
|---------|-------|
| Service | Hosting |
| Repository | `PrizrakZamkov/DevOps-Core-Course-Prizrak` |
| Framework | None / static |
| Build command | empty |
| Output directory | `labs/lab18` |
| Entry file | `index.html` |

## Local IPFS Node

Run Kubo IPFS with Docker:

```powershell
docker run -d --name ipfs `
  -p 4001:4001 `
  -p 8080:8080 `
  -p 5001:5001 `
  ipfs/kubo:latest
```

Open the Web UI:

```text
http://localhost:5001/webui
```

Add the Lab 18 site:

```powershell
docker cp labs/lab18/index.html ipfs:/index.html
docker exec ipfs ipfs add /index.html
```

Expected output:

```text
added QmNh6rpwAgB5L9W8zEZKmheWAYcGZkEZHuso7AseLTWrsu index.html
```

Access through the local gateway:

```powershell
curl http://127.0.0.1:8080/ipfs/QmNh6rpwAgB5L9W8zEZKmheWAYcGZkEZHuso7AseLTWrsu
```

Local CID:

```text
QmNh6rpwAgB5L9W8zEZKmheWAYcGZkEZHuso7AseLTWrsu
```

Pin status:

```text
QmNh6rpwAgB5L9W8zEZKmheWAYcGZkEZHuso7AseLTWrsu recursive
```

## 4EVERLAND Deployment

Dashboard:

```text
https://www.4everland.org/
```

Steps:

1. Create or log into a 4EVERLAND account.
2. Open Hosting.
3. Create a new project.
4. Import the GitHub repository.
5. Select the branch with Lab 18 files.
6. Use the static settings from the table above.
7. Deploy.

Deployment URLs to record after live deployment:

```text
4EVERLAND project URL: https://devops-core-course-prizrak-hcps.ipfs.4everland.app
IPFS gateway URL:     https://ipfs.io/ipfs/bafybeic2csltdzhspgwxjqyxl7dm3vs2uh6kp7urhnlbtg4lkq3264f7sq
CID:                  bafybeic2csltdzhspgwxjqyxl7dm3vs2uh6kp7urhnlbtg4lkq3264f7sq
```

Note: `https://ipfs.4everland.link/ipfs/<CID>` returned `domain not configured`, so the verified public gateway for the report is `ipfs.io`.

## Bucket and Pinning

Bucket plan:

```text
Bucket name: devops-core-lab18
Files:
  labs/lab18/index.html
  app_python/docs/LAB18.md
  app_python/docs/lab18screens/
```

Upload through 4EVERLAND Bucket and record:

| Item | CID |
|------|-----|
| `index.html` | record after live Bucket upload |
| screenshots folder | record after live Bucket upload |
| full lab folder | record after live Bucket upload |

Gateway checks:

```text
https://devops-core-course-prizrak-hcps.ipfs.4everland.app
https://ipfs.io/ipfs/bafybeic2csltdzhspgwxjqyxl7dm3vs2uh6kp7urhnlbtg4lkq3264f7sq
https://dweb.link/ipfs/bafybeic2csltdzhspgwxjqyxl7dm3vs2uh6kp7urhnlbtg4lkq3264f7sq
```

## IPFS and IPNS Notes

| Concept | Meaning |
|---------|---------|
| IPFS CID | Immutable content identifier. Same content gives same CID. Changed content gives a new CID. |
| Pinning | Keeps content available and prevents garbage collection on the pinning node/service. |
| Gateway | HTTP access point for browser-friendly IPFS access. |
| IPNS | Mutable pointer that can point to the latest CID while keeping one stable name. |
| 4EVERLAND project URL | Stable URL managed by 4EVERLAND while deployments can produce new CIDs. |

## Update Test

Make a visible change:

```html
<div class="hero-badge">
  <span>&#x2713;</span> 2026 Edition - deployed with 4EVERLAND and IPFS
</div>
```

Redeploy in 4EVERLAND.

Expected:

```text
Project URL stays the same.
IPFS CID changes because content changed.
Old CID still points to the old content if it remains pinned.
```

## Traditional Hosting vs IPFS/4EVERLAND

| Aspect | Traditional Hosting | IPFS/4EVERLAND |
|--------|---------------------|----------------|
| Content addressing | URL points to server location | CID points to content hash |
| Single point of failure | Server, region, or provider outage can break access | Any node or gateway with the content can serve it |
| Censorship resistance | Lower, provider can remove or block content | Higher when content is pinned by multiple parties |
| Update mechanism | Mutate files behind same URL | New CID for new content, stable URL/IPNS can point to latest |
| Cost model | Pay for servers, platform, bandwidth | Pay for pinning, hosting, gateway bandwidth |
| Speed/latency | Very fast with CDN and origin control | Depends on gateway/cache/pinning location |
| Best use cases | Dynamic apps, APIs, private systems | Static sites, public assets, archives, verifiable files |

## Recommendation

Use decentralized hosting when:

- the content is static
- public availability matters
- content integrity and verifiable hashes are useful
- the project benefits from multiple gateways and pinning

Use traditional hosting when:

- the app has a backend API
- content changes very frequently
- strict access control is required
- low latency and predictable operations matter most

For this lab, 4EVERLAND is a good fit because the provided site is static and can be served directly from IPFS.

## Screenshots

Generated local evidence:

```text
app_python/docs/lab18screens/01-lab18-static-site.png
app_python/docs/lab18screens/02-lab18-ipfs-node.png
app_python/docs/lab18screens/03-lab18-4everland-deploy.png
app_python/docs/lab18screens/04-lab18-gateway-pinning.png
```

Playwright command:

```powershell
npx.cmd playwright test tests/lab18-evidence.spec.ts --project=chromium
```

## Live Verification Commands

After Docker is available:

```powershell
docker version
docker ps
docker exec ipfs ipfs id
docker exec ipfs ipfs pin ls
curl http://127.0.0.1:8080/ipfs/QmNh6rpwAgB5L9W8zEZKmheWAYcGZkEZHuso7AseLTWrsu
```

After 4EVERLAND deployment:

```powershell
curl https://devops-core-course-prizrak-hcps.ipfs.4everland.app
curl https://ipfs.io/ipfs/bafybeic2csltdzhspgwxjqyxl7dm3vs2uh6kp7urhnlbtg4lkq3264f7sq
curl https://dweb.link/ipfs/bafybeic2csltdzhspgwxjqyxl7dm3vs2uh6kp7urhnlbtg4lkq3264f7sq
```
