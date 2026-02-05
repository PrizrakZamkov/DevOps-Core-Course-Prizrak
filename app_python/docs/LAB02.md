# Lab 02 — Docker Containerization

## 1. Docker Best Practices Applied

### Non-root user
The container runs under a non-root user created explicitly in the Dockerfile.  
This reduces security risks by limiting privileges in case of container compromise.

### Layer caching optimization
Dependencies are installed before copying application source code.  
This allows Docker to reuse cached layers when application code changes.

### Minimal base image
The image is based on `python:3.13-slim`, which provides a balance between size and compatibility.

### .dockerignore usage
Unnecessary files such as virtual environments, git metadata, and cache files are excluded from the build context.  
This reduces build time and final image size.

---

## 2. Image Information & Decisions

### Base image
`python:3.13-slim` was chosen to ensure:
- a fixed Python version
- smaller image compared to full images
- better compatibility than alpine-based images

### Image size
The final image size is relatively small due to:
- slim base image
- no build tools
- no cached pip files

### Layer structure
The Dockerfile separates:
1. Base system
2. Dependency installation
3. Application code

This improves rebuild performance.

---

## 3. Build & Run Process

### Image build
```text
docker build -t lab02-python .
Container run
text

docker run -p 6000:6000 lab02-python
Endpoint test
text

curl http://localhost:6000/health
Docker Hub
Image available at:
https://hub.docker.com/r/prizrakzamkov/lab02-python

4. Technical Analysis
If application files were copied before installing dependencies, any code change would invalidate the cache and force dependency reinstallation.

Running as root would increase the attack surface of the container.

The .dockerignore file prevents unnecessary files from being sent to the Docker daemon, improving build speed and reducing image size.

5. Challenges & Solutions
One potential issue was file permission management when switching to a non-root user.
This was resolved by copying files before switching users.

The lab improved understanding of Docker layer caching and container security.

---