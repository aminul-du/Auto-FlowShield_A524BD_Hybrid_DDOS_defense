# Step 1: Create the log directory with correct permissions
sudo mkdir -p /var/log/mcnms
sudo chown -R www-data:www-data /var/log/mcnms
sudo chmod 755 /var/log/mcnms
sudo touch /var/log/mcnms/mcnms.log
sudo chown www-data:www-data /var/log/mcnms/mcnms.log
sudo chmod 644 /var/log/mcnms/mcnms.log

# Step 2: Fix app.py to handle log file gracefully
sudo tee /opt/mcore-nms/app.py << 'EOF'
#!/usr/bin/env python3
"""
MCoreNMS Pro - Complete 360° Network Visibility Platform
Project ID: MeticulousCoreNMS@42026V1
Owner: Meticulous Core Global
"""

import os
import sys
import socket
import time
import json
import threading
import subprocess
from datetime import datetime, timedelta
from collections import defaultdict
import logging

# Configure logging - FIXED: Handle permission errors gracefully
log_file = '/var/log/mcnms/mcnms.log'
try:
    # Try to create log directory if it doesn't exist
    os.makedirs('/var/log/mcnms', exist_ok=True)
    # Try to open log file
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),  # Always print to console
            logging.FileHandler(log_file)  # Try file logging
        ]
    )
except Exception as e:
    # If file logging fails, just use console
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[logging.StreamHandler()]
    )
    print(f"Warning: Could not log to file: {e}")

logger = logging.getLogger(__name__)

# Flask for web interface
from flask import Flask, jsonify, render_template_string

# ================================================================
# CONFIGURATION - All Targets We Monitor
# ================================================================

MONITOR_TARGETS = {
    'whatsapp': {
        'name': 'WhatsApp',
        'asn': 'AS32934',
        'company': 'Meta',
        'targets': [
            {'region': 'Global', 'host': 'whatsapp.com', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'whatsapp.com', 'port': 80, 'protocol': 'tcp', 'type': 'HTTP'},
            {'region': 'Global', 'host': 'whatsapp.com', 'port': 5222, 'protocol': 'tcp', 'type': 'XMPP'},
            {'region': 'Global', 'host': 'stun.whatsapp.com', 'port': 3478, 'protocol': 'udp', 'type': 'STUN'},
            {'region': 'Global', 'host': 'stun.whatsapp.com', 'port': 19302, 'protocol': 'udp', 'type': 'TURN'},
        ]
    },
    'imo': {
        'name': 'IMO',
        'asn': 'AS36131',
        'company': 'PageBites',
        'targets': [
            {'region': 'Global', 'host': 'imo.im', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'imo.im', 'port': 80, 'protocol': 'tcp', 'type': 'HTTP'},
            {'region': 'Global', 'host': 'stun.imo.im', 'port': 3478, 'protocol': 'udp', 'type': 'STUN'},
        ]
    },
    'bigo': {
        'name': 'BIGO Live',
        'asn': 'AS10122',
        'company': 'BIGO',
        'targets': [
            {'region': 'Singapore', 'host': '45.249.47.148', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Singapore', 'host': '45.249.47.148', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Mumbai', 'host': '164.90.73.0', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Dhaka', 'host': '164.90.84.180', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Riyadh', 'host': '45.249.46.0', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Frankfurt', 'host': '164.90.72.177', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
        ]
    },
    'google': {
        'name': 'Google',
        'asn': 'AS15169',
        'company': 'Google',
        'targets': [
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
        ]
    }
}

# ================================================================
# PROBE FUNCTIONS
# ================================================================

def tcp_ping(host, port, timeout=5):
    """Measure TCP handshake RTT"""
    try:
        start = time.time()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((host, port))
        end = time.time()
        sock.close()
        return round((end - start) * 1000, 2)
    except Exception:
        return None

def udp_ping(host, port, timeout=3):
    """Measure UDP round-trip time"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        probe_data = b'\x00\x01\x00\x00\x00\x00\x00\x00'
        start = time.time()
        sock.sendto(probe_data, (host, port))
        sock.recvfrom(1024)
        end = time.time()
        sock.close()
        return round((end - start) * 1000, 2)
    except Exception:
        return None

def run_probe(target):
    """Run appropriate probe based on protocol"""
    protocol = target.get('protocol', 'tcp')
    host = target['host']
    port = target.get('port', 443)
    
    if protocol == 'tcp':
        return tcp_ping(host, port)
    elif protocol == 'udp':
        return udp_ping(host, port)
    else:
        return tcp_ping(host, port)

# ================================================================
# DATA COLLECTION
# ================================================================

class MetricsCollector:
    def __init__(self):
        self.metrics = defaultdict(list)
        self.last_collection = None
        self.running = True
    
    def collect_all(self):
        """Collect metrics from all targets"""
        all_metrics = []
        
        for service_name, service_config in MONITOR_TARGETS.items():
            for target in service_config['targets']:
                rtt = run_probe(target)
                
                metric = {
                    'service': service_config['name'],
                    'company': service_config['company'],
                    'region': target['region'],
                    'host': target['host'],
                    'port': target['port'],
                    'protocol': target['protocol'],
                    'type': target.get('type', 'unknown'),
                    'rtt': rtt,
                    'timestamp': datetime.now().isoformat(),
                    'status': self._get_status(rtt)
                }
                all_metrics.append(metric)
                
                # Store in history
                key = f"{service_name}_{target['region']}_{target['protocol']}"
                self.metrics[key].append(metric)
                
                # Keep last 24 hours
                cutoff = datetime.now() - timedelta(hours=24)
                self.metrics[key] = [
                    m for m in self.metrics[key]
                    if datetime.fromisoformat(m['timestamp']) > cutoff
                ]
                
                time.sleep(0.3)  # Small delay
        
        self.last_collection = datetime.now()
        return all_metrics
    
    def _get_status(self, rtt):
        if rtt is None:
            return 'unknown'
        elif rtt > 200:
            return 'critical'
        elif rtt > 100:
            return 'warning'
        else:
            return 'normal'
    
    def get_latest_metrics(self):
        latest = []
        for key, history in self.metrics.items():
            if history:
                latest.append(history[-1])
        return latest
    
    def start_background_collection(self, interval=300):
        def collect_loop():
            while self.running:
                try:
                    logger.info(f"Starting collection at {datetime.now()}")
                    self.collect_all()
                    logger.info(f"Collection completed at {datetime.now()}")
                except Exception as e:
                    logger.error(f"Collection error: {e}")
                time.sleep(interval)
        
        thread = threading.Thread(target=collect_loop, daemon=True)
        thread.start()
        logger.info(f"Background collection started (interval: {interval}s)")
        return thread

# ================================================================
# FLASK APPLICATION
# ================================================================

app = Flask(__name__)
collector = MetricsCollector()

# HTML Template (simplified for quick fix)
DASHBOARD_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>MCoreNMS Pro - Network Monitor</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; margin: 20px; background: #f0f2f5; }
        h1 { color: #1a1a2e; }
        .card { background: white; border-radius: 8px; padding: 20px; margin: 10px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #1a1a2e; color: white; }
        .critical { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .normal { color: green; }
        .badge { padding: 4px 8px; border-radius: 4px; color: white; }
        .badge-critical { background: red; }
        .badge-warning { background: orange; }
        .badge-normal { background: green; }
        .refresh { float: right; margin-bottom: 10px; }
        button { padding: 8px 16px; background: #1a1a2e; color: white; border: none; border-radius: 4px; cursor: pointer; }
    </style>
    <script>
        function refreshData() {
            fetch('/api/metrics')
                .then(res => res.json())
                .then(data => {
                    const tbody = document.getElementById('metricsBody');
                    tbody.innerHTML = '';
                    data.forEach(m => {
                        const row = tbody.insertRow();
                        row.insertCell(0).innerHTML = `<strong>${m.service}</strong>`;
                        row.insertCell(1).textContent = m.region;
                        row.insertCell(2).textContent = m.protocol.toUpperCase();
                        row.insertCell(3).textContent = m.rtt ? m.rtt + ' ms' : 'N/A';
                        row.insertCell(4).innerHTML = `<span class="badge badge-${m.status}">${m.status}</span>`;
                        row.insertCell(5).textContent = new Date(m.timestamp).toLocaleTimeString();
                    });
                    document.getElementById('lastUpdate').textContent = new Date().toLocaleString();
                });
        }
        setInterval(refreshData, 30000);
        window.onload = refreshData;
    </script>
</head>
<body>
    <h1>📡 MCoreNMS Pro - Network Monitor</h1>
    <p>Project ID: MeticulousCoreNMS@42026V1 | Owner: Meticulous Core Global</p>
    
    <div class="card">
        <button class="refresh" onclick="refreshData()">🔄 Refresh</button>
        <h3>Network Performance Metrics</h3>
        <div style="overflow-x: auto;">
            <table>
                <thead><tr><th>Service</th><th>Region</th><th>Protocol</th><th>RTT</th><th>Status</th><th>Updated</th></tr></thead>
                <tbody id="metricsBody"><tr><td colspan="6">Loading...</td></tr></tbody>
            </table>
        </div>
        <p>Last updated: <span id="lastUpdate">-</span> (auto-refresh every 30s)</p>
    </div>
    
    <div class="card">
        <h3>Monitored Services</h3>
        <ul>
            <li><strong>WhatsApp (Meta AS32934)</strong> - HTTPS, XMPP, STUN, TURN</li>
            <li><strong>IMO (PageBites AS36131)</strong> - HTTPS, STUN</li>
            <li><strong>BIGO Live (AS10122)</strong> - Singapore, Mumbai, Dhaka, Riyadh, Frankfurt</li>
            <li><strong>Google (AS15169)</strong> - HTTPS, QUIC</li>
        </ul>
    </div>
</body>
</html>
'''

@app.route('/')
@app.route('/mcnms')
@app.route('/mcnms/')
def dashboard():
    return render_template_string(DASHBOARD_TEMPLATE)

@app.route('/api/metrics')
def api_metrics():
    return jsonify(collector.get_latest_metrics())

@app.route('/api/health')
def api_health():
    return jsonify({
        'status': 'ok',
        'project_id': 'MeticulousCoreNMS@42026V1',
        'services': list(MONITOR_TARGETS.keys())
    })

# ================================================================
# MAIN
# ================================================================

if __name__ == '__main__':
    print("=" * 60)
    print("MCoreNMS Pro - Starting...")
    print("Project ID: MeticulousCoreNMS@42026V1")
    print("=" * 60)
    
    # Start background collection
    collector.start_background_collection(interval=300)
    
    # Start Flask
    app.run(host='127.0.0.1', port=5000, debug=False, threaded=True)
EOF

# Step 3: Fix wsgi.py
sudo tee /opt/mcore-nms/wsgi.py << 'EOF'
import sys
import os

# Add the application directory to Python path
sys.path.insert(0, '/opt/mcore-nms')

# Ensure log directory exists with proper permissions
try:
    os.makedirs('/var/log/mcnms', exist_ok=True)
    os.chmod('/var/log/mcnms', 0o755)
except Exception:
    pass

# Import the Flask app
from app import app as application
EOF

# Step 4: Set all permissions correctly
sudo chown -R www-data:www-data /opt/mcore-nms
sudo chmod -R 755 /opt/mcore-nms
sudo chmod 644 /opt/mcore-nms/app.py
sudo chmod 644 /opt/mcore-nms/wsgi.py

# Step 5: Create and set log directory permissions
sudo mkdir -p /var/log/mcnms
sudo touch /var/log/mcnms/mcnms.log
sudo chown -R www-data:www-data /var/log/mcnms
sudo chmod 755 /var/log/mcnms
sudo chmod 644 /var/log/mcnms/mcnms.log

# Step 6: Restart Apache
sudo systemctl restart apache2

# Step 7: Test
echo "Testing..."
sleep 2
curl -s http://localhost/mcnms/api/health
echo ""

# Step 8: Check Apache error log
sudo tail -5 /var/log/apache2/error.log