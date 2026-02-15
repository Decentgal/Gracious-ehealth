AN e-HEALTH APPLICATION DEPLOYMENT PIPELINE

This repository implements a security-first CI/CD pipeline for a Python-based eHealth application. The pipeline is designed to protect sensitive patient data by enforcing security controls at build time and runtime using industry-standard DevSecOps tools. Every code push is automatically scanned, tested, and validated before being approved for deployment.


Application overview

This application is a lightweight Flask API that exposes a health status endpoint while enforcing strong HTTP security headers to mitigate common web vulnerabilities like:
- Vulnerable & outdated components:
This happens when your infrastructure is using libraries or OS packages with known vulnerabilities. I prevented this using Trivy to run container automated scanning.

- Server & Container escape risks:
Here, attackers exploit container weaknesses. I prevented this using a Distroless image and a Non-root container.

- Cross-Site Scripting (XSS) attacks:
This occurs when malicious scripts run in users’ browsers.  I prevented this using CSP headers.


Endpoint

GET /

Response

{
  "status": "Green",
  "security": "Hardened"
}


The tech stack I used are:

- Programming language: Python 3.13.12
- Framework: Flask
- Containerization: Docker (Multi-stage, Distroless runtime)
- CI/CD: GitHub Actions
- SAST & Image Scanning: Trivy
- DAST: OWASP ZAP
- Version Control: Git & GitHub



Project Structure

├── gracious_app.py        =  Flask application with security headers

├── gracy.txt              =  Dependency pinning & security fixes

├── Dockerfile             =  Multi-stage hardened container build

├── .github/workflows/

   └── pipeline.yml        =  CI/CD security pipeline

├── README.md              =  Technical Documentation


Project steps and implemention processes I took were:

1. Application-level hardening:The Flask application enforces multiple HTTP security headers, including:

- X-Content-Type-Options
- X-Frame-Options
- Content-Security-Policy
- X-XSS-Protection
- Permissions-Policy
- Cross-Origin-Opener-Policy
- Cross-Origin-Embedder-Policy
- Cache-Control
- Server version leakage is explicitly disabled to prevent fingerprinting.


2. Dependency security: Dependencies are explicitly pinned in gracy.txt to prevent:

- Dependency confusion attacks
- Introduction of known vulnerable versions
- Additional packages are included to address Trivy-detected security issues.


3. Hardened Container Image: The application uses a multi-stage Docker build:

- Builder Stage: Installs dependencies in an isolated environment
- Runtime Stage: Uses a Distroless Python image, removing shells and package managers


4. Security benefits:
- Minimal attack surface
- No root access (USER nonroot)
- Reduced container size


5. CI/CD Security Pipeline: The GitHub Actions pipeline automatically runs on every push using the following pipeline stages in this order:

- Code Push
- Checkout Repository
- Trivy Config Scan (Dockerfile)
- Docker Image Build
- Trivy Image Scan (SAST)
- Deploy Container (Isolated)
- OWASP ZAP Scan (DAST)
- Security Report Upload
- Deployment Approval


6. Static Application Security Testing (SAST) tool I used was Trivy. It carried out the following:

- scans Dockerfile configurations
- scans OS packages and Python dependencies
- blocks builds on CRITICAL and HIGH vulnerabilities
  

7. Dynamic Application Security Testing (DAST) tool I used was  OWASP ZAP (Baseline Scan)
- Application is deployed in a temporary container
- ZAP performs automated security testing
- Findings are reported but do not block deployment (configurable)


8. Security reports are uploaded as pipeline artifacts:
- HTML
- Markdown
- JSON


9. How to run locally and the prerequisites you need:
- Python 3.11+
- Docker
- Git
- Trivy (optional for local scans)
- Clone the Repository
- git clone https://github.com/Decentgal/Gracious-ehealth.git
- cd Decentgal


10. You can also run this application locally without Docker using:
- pip install -r gracy.txt
- python gracious_app.py


Visit: http://localhost:5000


11. You can build and run with Docker

- docker build -t ehealth-app .
- docker run -p 5000:5000 ehealth-app


12. You can also run Trivy locally (optional)
trivy image ehealth-app


13. Security Outcome: In the end, only codes that:

- Passes Trivy configuration scans
- Passes Trivy image vulnerability scans
- Successfully runs OWASP ZAP security tests

are allowed to proceed toward deployment.


This ensures a the first-step to securing a reliable, and privacy-focused experience for e-patients and healthcare workers.
