An e-Health Application deployment pipeline

This repository implements a security-first CI/CD pipeline for a Python-based eHealth application. The pipeline is designed to protect sensitive patient data by enforcing security controls at build time and runtime using industry-standard DevSecOps tools. Every code push is automatically scanned, tested, and validated before being approved for deployment.

Application Overview

The application is a lightweight Flask API that exposes a health status endpoint while enforcing strong HTTP security headers to mitigate common web vulnerabilities.

Endpoint

GET /

Response

{
  "status": "Green",
  "security": "Hardened"
}


The tech stack I used are:
Language: Python 3.11
Framework: Flask
Containerization: Docker (Multi-stage, Distroless runtime)
CI/CD: GitHub Actions
SAST & Image Scanning: Trivy
DAST: OWASP ZAP
Version Control: Git & GitHub


Project Structure

├── gracious_app.py        # Flask application with security headers

├── gracy.txt              # Dependency pinning & security fixes

├── Dockerfile             # Multi-stage hardened container build

├── .github/workflows/

│   └── pipeline.yml       # CI/CD security pipeline

└── README.md


Security controls I implemented were:
Application-Level Hardening: The Flask application enforces multiple HTTP security headers, including:

X-Content-Type-Options
X-Frame-Options
Content-Security-Policy
X-XSS-Protection
Permissions-Policy
Cross-Origin-Opener-Policy
Cross-Origin-Embedder-Policy
Cache-Control
Server version leakage is explicitly disabled to prevent fingerprinting.


Dependency security: Dependencies are explicitly pinned in gracy.txt to prevent:
Dependency confusion attacks
Introduction of known vulnerable versions
Additional packages are included to address Trivy-detected security issues.


Hardened Container Image: The application uses a multi-stage Docker build:
Builder Stage: Installs dependencies in an isolated environment
Runtime Stage: Uses a Distroless Python image, removing shells and package managers


Security benefits:
Minimal attack surface
No root access (USER nonroot)
Reduced container size


CI/CD Security Pipeline: The GitHub Actions pipeline automatically runs on every push.
Pipeline Stages

Code Push
   ↓

Checkout Repository
   ↓

Trivy Config Scan (Dockerfile)
   ↓

Docker Image Build
   ↓

Trivy Image Scan (SAST)
   ↓

Deploy Container (Isolated)
   ↓

OWASP ZAP Scan (DAST)
   ↓

Security Report Upload
   ↓

Deployment Approval



Static Application Security Testing (SAST) tool I used was Trivy. It carried out the following:

- scans Dockerfile configurations
- scans OS packages and Python dependencies
- blocks builds on CRITICAL and HIGH vulnerabilities
  

Dynamic Application Security Testing (DAST) tool I used was  OWASP ZAP (Baseline Scan)
- Application is deployed in a temporary container
- ZAP performs automated security testing
- Findings are reported but do not block deployment (configurable)


Security reports are uploaded as pipeline artifacts:
- HTML
- Markdown
- JSON


How to run locally and the prerequisites you need:
- Python 3.11+
- Docker
- Git
- Trivy (optional for local scans)
- Clone the Repository
- git clone https://github.com/Decentgal/Gracious-ehealth.git
- cd Decentgal


You can also run this application locally without Docker using:
pip install -r gracy.txt
python gracious_app.py


Visit: http://localhost:5000


You can build and run with Docker

docker build -t ehealth-app .
docker run -p 5000:5000 ehealth-app


You can also run Trivy locally (optional)
trivy image ehealth-app


Security Outcome

Only code that:

Passes Trivy configuration scans
Passes Trivy image vulnerability scans
Successfully runs OWASP ZAP security tests is allowed to proceed toward deployment.


This ensures a secure, reliable, and privacy-focused experience for e-patients and healthcare staff.
