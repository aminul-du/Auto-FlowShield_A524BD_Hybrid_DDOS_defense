# ==========================================
# STEP 1: Fix Log Directory Permissions
# ==========================================
sudo mkdir -p /var/log/mcnms
sudo chown -R www-data:www-data /var/log/mcnms
sudo chmod 755 /var/log/mcnms
sudo touch /var/log/mcnms/mcnms.log
sudo chown www-data:www-data /var/log/mcnms/mcnms.log
sudo chmod 644 /var/log/mcnms/mcnms.log

# Verify permissions
ls -la /var/log/mcnms/
# Should show: drwxr-xr-x www-data www-data  and -rw-r--r-- www-data www-data

# ==========================================
# STEP 2: Fix Application Directory
# ==========================================
sudo chown -R www-data:www-data /opt/mcore-nms
sudo chmod -R 755 /opt/mcore-nms
sudo chmod 644 /opt/mcore-nms/app.py
sudo chmod 644 /opt/mcore-nms/wsgi.py

# ==========================================
# STEP 3: Create a SIMPLER app.py that doesn't use file logging
# ==========================================
sudo tee /opt/mcore-nms/app.py << 'EOF'
#!/usr/bin/env python3
"""
MCoreNMS Pro - Network Monitoring System
Project ID: MeticulousCoreNMS@42026V1
"""

import os
import sys
import socket
import time
import threading
from datetime import datetime
from flask import Flask, jsonify, render_template_string

# Simple console logging only (no file to avoid permission issues)
print("MCoreNMS Pro starting...")

# Flask app
app = Flask(__name__)

# Store metrics in memory
metrics_store = []
last_collection_time = None

# ================================================================
# MONITORING TARGETS
# ================================================================

MONITOR_TARGETS = {
    'whatsapp': {
        'name': 'WhatsApp',
        'targets': [
            {'region': 'Global', 'host': 'whatsapp.com', 'port': 443, 'protocol': 'tcp'},
            {'region': 'Global', 'host': 'whatsapp.com', 'port': 80, 'protocol': 'tcp'},
            {'region': 'Global', 'host': 'stun.whatsapp.com', 'port': 3478, 'protocol': 'udp'},
        ]
    },
    'imo': {
        'name': 'IMO',
        'targets': [
            {'region': 'Global', 'host': 'imo.im', 'port': 443, 'protocol': 'tcp'},
            {'region': 'Global', 'host': 'imo.im', 'port': 80, 'protocol': 'tcp'},
        ]
    },
    'bigo': {
        'name': 'BIGO Live',
        'targets': [
            {'region': 'Singapore', 'host': '45.249.47.148', 'port': 443, 'protocol': 'tcp'},
            {'region': 'Mumbai', 'host': '164.90.73.0', 'port': 443, 'protocol': 'tcp'},
            {'region': 'Dhaka', 'host': '164.90.84.180', 'port': 443, 'protocol': 'tcp'},
        ]
    },
    'google': {
        'name': 'Google',
        'targets': [
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'tcp'},
        ]
    }
}

# ================================================================
# PROBE FUNCTIONS
# ================================================================

def tcp_ping(host, port, timeout=5):
    """Measure TCP connection time"""
    try:
        start = time.time()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((host, port))
        end = time.time()
        sock.close()
        return round((end - start) * 1000, 2)
    except Exception as e:
        print(f"TCP ping failed to {host}:{port} - {e}")
        return None

def udp_ping(host, port, timeout=3):
    """Measure UDP response time"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        start = time.time()
        sock.sendto(b'ping', (host, port))
        sock.recvfrom(1024)
        end = time.time()
        sock.close()
        return round((end - start) * 1000, 2)
    except Exception:
        return None

def run_probe(target):
    """Run appropriate probe"""
    if target['protocol'] == 'tcp':
        return tcp_ping(target['host'], target['port'])
    elif target['protocol'] == 'udp':
        return udp_ping(target['host'], target['port'])
    return None

# ================================================================
# DATA COLLECTION
# ================================================================

def collect_metrics():
    """Collect all metrics"""
    global metrics_store, last_collection_time
    
    print(f"Starting data collection at {datetime.now()}")
    new_metrics = []
    
    for service_name, service_config in MONITOR_TARGETS.items():
        for target in service_config['targets']:
            rtt = run_probe(target)
            
            metric = {
                'service': service_config['name'],
                'region': target['region'],
                'host': target['host'],
                'port': target['port'],
                'protocol': target['protocol'],
                'rtt': rtt,
                'timestamp': datetime.now().isoformat(),
                'status': 'normal' if rtt and rtt < 100 else ('warning' if rtt and rtt < 200 else 'critical') if rtt else 'unknown'
            }
            new_metrics.append(metric)
            print(f"  {service_config['name']} - {target['region']}: {rtt}ms")
            time.sleep(0.2)
    
    metrics_store = new_metrics
    last_collection_time = datetime.now()
    print(f"Collection complete. Stored {len(metrics_store)} metrics")
    return metrics_store

def background_collector():
    """Run in background thread"""
    while True:
        try:
            collect_metrics()
        except Exception as e:
            print(f"Collection error: {e}")
        time.sleep(300)  # Every 5 minutes

# Start background thread
collector_thread = threading.Thread(target=background_collector, daemon=True)
collector_thread.start()
print("Background collector thread started")

# Run initial collection
collect_metrics()

# ================================================================
# HTML TEMPLATE
# ================================================================

DASHBOARD_HTML = '''
<!DOCTYPE html>
<html>
<head>
    <title>MCoreNMS Pro - Network Monitor</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f0f2f5; }
        h1 { color: #1a1a2e; }
        .header { background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .card { background: white; border-radius: 8px; padding: 20px; margin: 10px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #1a1a2e; color: white; }
        .critical { color: #dc3545; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .normal { color: #28a745; font-weight: bold; }
        .badge { padding: 4px 12px; border-radius: 20px; color: white; font-size: 12px; }
        .badge-critical { background: #dc3545; }
        .badge-warning { background: #ffc107; color: #333; }
        .badge-normal { background: #28a745; }
        .badge-unknown { background: #6c757d; }
        .refresh-btn { float: right; padding: 8px 16px; background: #1a1a2e; color: white; border: none; border-radius: 5px; cursor: pointer; }
        .stats { display: flex; gap: 20px; margin-bottom: 20px; flex-wrap: wrap; }
        .stat-box { background: white; padding: 15px; border-radius: 8px; flex: 1; min-width: 150px; text-align: center; }
        .stat-number { font-size: 32px; font-weight: bold; }
        .last-update { margin-top: 20px; text-align: center; color: #666; font-size: 12px; }
    </style>
    <script>
        function refreshData() {
            fetch('/api/metrics')
                .then(res => res.json())
                .then(data => {
                    const tbody = document.getElementById('metricsBody');
                    tbody.innerHTML = '';
                    let critical = 0, warning = 0, normal = 0;
                    data.forEach(m => {
                        const row = tbody.insertRow();
                        row.insertCell(0).innerHTML = `<strong>${m.service}</strong>`;
                        row.insertCell(1).textContent = m.region;
                        row.insertCell(2).textContent = m.protocol.toUpperCase();
                        row.insertCell(3).textContent = m.rtt ? m.rtt + ' ms' : 'N/A';
                        row.insertCell(4).innerHTML = `<span class="badge badge-${m.status}">${m.status.toUpperCase()}</span>`;
                        row.insertCell(5).textContent = new Date(m.timestamp).toLocaleTimeString();
                        if (m.status === 'critical') critical++;
                        else if (m.status === 'warning') warning++;
                        else if (m.status === 'normal') normal++;
                    });
                    document.getElementById('criticalCount').textContent = critical;
                    document.getElementById('warningCount').textContent = warning;
                    document.getElementById('normalCount').textContent = normal;
                    document.getElementById('totalCount').textContent = data.length;
                    document.getElementById('lastUpdateTime').textContent = new Date().toLocaleString();
                });
        }
        setInterval(refreshData, 30000);
        window.onload = refreshData;
    </script>
</head>
<body>
    <div class="header">
        <h1>📡 MCoreNMS Pro</h1>
        <p>Project ID: MeticulousCoreNMS@42026V1 | Owner: Meticulous Core Global</p>
    </div>
    
    <div class="stats">
        <div class="stat-box"><div class="stat-number" id="totalCount">-</div><div>Total Monitors</div></div>
        <div class="stat-box"><div class="stat-number" style="color:#dc3545" id="criticalCount">-</div><div>Critical</div></div>
        <div class="stat-box"><div class="stat-number" style="color:#ffc107" id="warningCount">-</div><div>Warning</div></div>
        <div class="stat-box"><div class="stat-number" style="color:#28a745" id="normalCount">-</div><div>Healthy</div></div>
    </div>
    
    <div class="card">
        <button class="refresh-btn" onclick="refreshData()">🔄 Refresh Now</button>
        <h3>Network Performance Metrics</h3>
        <div style="overflow-x: auto;">
            <table id="metricsTable">
                <thead><tr><th>Service</th><th>Region</th><th>Protocol</th><th>RTT</th><th>Status</th><th>Updated</th></tr></thead>
                <tbody id="metricsBody"><tr><td colspan="6">Loading metrics... (first collection takes 30-60 seconds)</td></tr></tbody>
            </table>
        </div>
    </div>
    
    <div class="last-update">
        Last auto-refresh: <span id="lastUpdateTime">-</span> (updates every 30 seconds)
    </div>
</body>
</html>
'''

# ================================================================
# ROUTES
# ================================================================

@app.route('/')
@app.route('/mcnms')
@app.route('/mcnms/')
def dashboard():
    return render_template_string(DASHBOARD_HTML)

@app.route('/api/metrics')
def api_metrics():
    return jsonify(metrics_store)

@app.route('/api/health')
def api_health():
    return jsonify({
        'status': 'ok',
        'project_id': 'MeticulousCoreNMS@42026V1',
        'metrics_count': len(metrics_store),
        'last_collection': last_collection_time.isoformat() if last_collection_time else None
    })

# ================================================================
# MAIN
# ================================================================

if __name__ == '__main__':
    print("=" * 60)
    print("MCoreNMS Pro - Starting...")
    print("Project ID: MeticulousCoreNMS@42026V1")
    print("=" * 60)
    app.run(host='127.0.0.1', port=5000, debug=False, threaded=True)
EOF

# ==========================================
# STEP 4: Update wsgi.py
# ==========================================
sudo tee /opt/mcore-nms/wsgi.py << 'EOF'
import sys
sys.path.insert(0, '/opt/mcore-nms')
from app import app as application
EOF

# ==========================================
# STEP 5: Set permissions again
# ==========================================
sudo chown -R www-data:www-data /opt/mcore-nms
sudo chmod 755 /opt/mcore-nms
sudo chmod 644 /opt/mcore-nms/app.py
sudo chmod 644 /opt/mcore-nms/wsgi.py

# ==========================================
# STEP 6: Restart Apache
# ==========================================
sudo systemctl restart apache2

# ==========================================
# STEP 7: Wait and Test
# ==========================================
echo "Waiting 10 seconds for Apache to start..."
sleep 10

echo ""
echo "Testing API..."
curl -s http://localhost/mcnms/api/health
echo ""

echo ""
echo "Testing metrics (should have data)..."
curl -s http://localhost/mcnms/api/metrics | head -200
echo ""

# ==========================================
# STEP 8: Check Apache error log (should be clean)
# ==========================================
echo ""
echo "Checking Apache error log (last 5 lines)..."
sudo tail -5 /var/log/apache2/error.log