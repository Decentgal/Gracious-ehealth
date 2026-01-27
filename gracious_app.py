from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.after_request
def apply_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['Content-Security-Policy'] = "default-src 'self'"
    response.headers['X-XSS-Protection'] = '1; mode=block'
    
    # NEW: Fix for "Server Leaks Version Information"
    response.headers['Server'] = 'Webserver' 
    
    # NEW: Fix for "Permissions Policy Header Not Set"
    response.headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
    
    # NEW: Fix for "Insufficient Site Isolation"
    response.headers['Cross-Origin-Opener-Policy'] = 'same-origin'
    response.headers['Cross-Origin-Embedder-Policy'] = 'require-corp'
    
    # NEW: Fix for "Storable and Cacheable Content" (Prevents sensitive info caching)
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, proxy-revalidate'
    
    return response

@app.route('/')
def hello():
    return jsonify({"status": "Green", "security": "Hardened"})

if __name__ == "__main__":
    # ESSENTIAL: Must be 0.0.0.0 for Docker networking to work
    app.run(host='0.0.0.0', port=5000, debug=False)