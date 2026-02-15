**AN e-HEALTH CI/CD PIPELINE COMPLIANT TO HIPAA, GDPR, OWASP Top 10, ISO 27001 & NIST standards.**

This repository implements a zero-trust architecture with a security-first CI/CD pipeline for a Python-based eHealth application. The pipeline is designed to protect patient data by enforcing security controls at build time and runtime using DevSecOps tools. Every code push is automatically scanned, tested, and validated before being approved for deployment to Production.

**Application Overview**

The application is a world-class secure healthcare environment with a focus on Zero-Trust architecture and automated security scanning. I moved away from static credentials toward the modern authentication best practice: **Identity Federation**.
This application is a lightweight Flask API that exposes a health status endpoint while enforcing strong HTTP security headers to mitigate common web vulnerabilities.

Endpoint

GET /

Response

{
  "status": "Green",
  "security": "Hardened"
}


**Technologies used**

- Infrastructure-as-Code: Terraform
- Cloud Provider: AWS (us-east-1)
- Infrastructure provisioned using Terraform: KMS, Secrets Manager, IAM OIDC Provider.
- Identity: OpenID Connect (OIDC) for GitHub Actions (Zero-Key Architecture).
- Data Security: Encryption was enforced using AWS KMS and secret rotation using Secrets Manager
- Language: Python 3.13.12
- Framework: Flask
- Containerization: Docker (Multi-stage, Distroless runtime)
- CI/CD: GitHub Actions
- SAST & Image Scanning: Trivy
- DAST: OWASP ZAP
- Version Control: Git & GitHub

**Industry compliance**
- **HIPAA:** Protected Health Information (PHI) is encrypted at rest and in transit via Secrets Manager.
- **ISO 27001:** Adheres to Access Control (A.9) and Cryptographic Controls (A.10).
- **NIST 800-207:** Implements Zero-Trust principles by assuming roles rather than using keys.
- **OWASP Top 10:** I integrated OWASP ZAP to scan for runtime vulnerabilities (XSS, SQLi).


**Local setup & testing**
1. Clone this repo: `git clone https://github.com/Decentgal/Gracious-ehealth.git`
2. Initialize Terraform: `terraform init`
3. Build & run: `docker build -t ehealth-app .`

**Project structure               and their contents**
.
├── gracious_app.py        Flask application with security headers
├── gracy.txt              Dependency pinning & security fixes
├──terraform/              IaC
|   └── iam.tf             Defines IAM resources (role & policy)
|   └── oidc.tf            Defines the GitHub OIDC trust setup
|   └── provider.tf        Defines how Terraform connects to AWS
|   └── main.tf            Core infrastructure resources (KMS, Secrets Manager)
├── Dockerfile             Multi-stage hardened container build
├── .github/workflows/
│   └── deploy.yml         CI/CD security pipeline
└── .gitignore             Credentials
└── README.md              Technical documentation


**Security controls implemented**

1. **Application-level hardening:** I enforced multiple HTTP security headers, including:

- X-Content-Type-Options
- X-Frame-Options
- Content-Security-Policy
- X-XSS-Protection
- Permissions-Policy
- Cross-Origin-Opener-Policy
- Cross-Origin-Embedder-Policy
- Cache-Control
- Server version leakage is explicitly disabled to prevent fingerprinting

2. **Dependency security**: Dependencies are explicitly pinned in gracy.txt to prevent:

- Dependency confusion attacks
- Introduction of known vulnerable versions
- Additional packages are included to address Trivy-detected security issues

3. **Hardened Container Image:** This application uses a multi-stage Docker build
- **Builder Stage:** Installs dependencies in an isolated environment
- **Runtime Stage:** Uses a Distroless Python image, removing shells and package managers

4. **Security benefits:**

- Minimal attack surface
- No root access (USER nonroot)
- Reduced container size

5. **CI/CD Security Pipeline:** The GitHub Actions pipeline automatically runs on every push using the following pipeline stages:

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


6. **Static Application Security Testing (SAST):** The tool used here is **Trivy* and it scans:

- Scans Dockerfile configurations
- Scans OS packages and Python dependencies
- Blocks builds on CRITICAL and HIGH vulnerabilities

7. **Dynamic Application Security Testing (DAST):** The tool I used here is OWASP ZAP for baseline scan. It does the following:

- Application is deployed in a temporary container
- ZAP performs automated security testing
- Findings are reported 
- Security reports are uploaded as pipeline artifacts:

**HTML*
**Markdown*
**JSON*

**Prerequisites you need to run locally:**

- Python 3.13.12
- Docker
- Git
- Terraform
- Trivy (optional for local scans)

**You can run this application locally without Docker*
- pip install -r gracy.txt
- python gracious_app.py

**On your browser, visit: 'http://localhost:5000' OR 'http://127.0.0.0:5000'

**You can build and run with Docker:*
- docker build -t ehealth-app .
- docker run -p 5000:5000 ehealth-app

**You can also run Trivy locally (optional)**
trivy image ehealth-app


8. **Security Outcome:** Only code that:

- Passes Trivy configuration scans
- Passes Trivy image vulnerability scans
- Successfully runs OWASP ZAP security tests is allowed to proceed toward deployment.


**In the end, this application ensures a reproducible, secure, reliable, and privacy-focused experience for everyday users, patients, and healthcare staff.*