#!/bin/bash
echo "========================================="
echo "MCoreNMS Pro - FINAL DEPLOYMENT"
echo "Project ID: MeticulousCoreNMS@42026V1"
echo "========================================="

# Create directories
sudo mkdir -p /opt/mcore-nms
sudo mkdir -p /var/www/html/mcnms
sudo mkdir -p /var/log/mcnms

# Create the collector script
sudo tee /opt/mcore-nms/collector.py << 'PYEOF'
#!/usr/bin/env python3
import socket, time, json, os
from datetime import datetime

DATA_FILE = '/var/www/html/mcnms/data.json'
MONITOR_TARGETS = {
    'whatsapp': {'name': 'WhatsApp', 'targets': [
        {'region': 'Global', 'host': 'whatsapp.com', 'port': 443, 'protocol': 'tcp'},
        {'region': 'Global', 'host': 'stun.whatsapp.com', 'port': 3478, 'protocol': 'udp'},
    ]},
    'imo': {'name': 'IMO', 'targets': [
        {'region': 'Global', 'host': 'imo.im', 'port': 443, 'protocol': 'tcp'},
    ]},
    'bigo': {'name': 'BIGO Live', 'targets': [
        {'region': 'Singapore', 'host': '45.249.47.148', 'port': 443, 'protocol': 'tcp'},
        {'region': 'Mumbai', 'host': '164.90.73.0', 'port': 443, 'protocol': 'tcp'},
        {'region': 'Dhaka', 'host': '164.90.84.180', 'port': 443, 'protocol': 'tcp'},
    ]},
    'google': {'name': 'Google', 'targets': [
        {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'tcp'},
    ]}
}

def tcp_ping(host, port):
    try:
        import socket
        start = time.time()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((host, port))
        rtt = (time.time() - start) * 1000
        sock.close()
        return round(rtt, 2)
    except:
        return None

def udp_ping(host, port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(3)
        start = time.time()
        sock.sendto(b'ping', (host, port))
        sock.recvfrom(1024)
        rtt = (time.time() - start) * 1000
        sock.close()
        return round(rtt, 2)
    except:
        return None

def get_status(rtt):
    if rtt is None: return 'unknown'
    elif rtt > 200: return 'critical'
    elif rtt > 100: return 'warning'
    else: return 'normal'

os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
all_metrics = []

for service, config in MONITOR_TARGETS.items():
    for target in config['targets']:
        if target['protocol'] == 'tcp':
            rtt = tcp_ping(target['host'], target['port'])
        else:
            rtt = udp_ping(target['host'], target['port'])
        
        all_metrics.append({
            'service': config['name'],
            'region': target['region'],
            'host': f"{target['host']}:{target['port']}",
            'protocol': target['protocol'].upper(),
            'rtt': rtt,
            'status': get_status(rtt),
            'time': datetime.now().strftime('%H:%M:%S')
        })

with open(DATA_FILE, 'w') as f:
    json.dump(all_metrics, f)

print(f"Collected {len(all_metrics)} metrics")
PYEOF

# Create HTML dashboard
sudo tee /var/www/html/mcnms/index.html << 'HTEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="30">
    <title>MCoreNMS Pro</title>
    <style>
        body { font-family: Arial; background: #f0f2f5; margin: 0; padding: 20px; }
        .header { background: #1a1a2e; color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .stats { display: flex; gap: 20px; margin-bottom: 20px; flex-wrap: wrap; }
        .stat-card { background: white; padding: 20px; border-radius: 10px; flex: 1; text-align: center; min-width: 120px; }
        .stat-number { font-size: 32px; font-weight: bold; }
        .card { background: white; border-radius: 10px; padding: 20px; margin-bottom: 20px; }
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
        .nav-links { display: flex; gap: 20px; margin-bottom: 20px; }
        .nav-link { background: white; padding: 10px 20px; border-radius: 8px; text-decoration: none; color: #1a1a2e; font-weight: bold; }
        .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        .last-update { text-align: right; font-size: 12px; color: #666; margin-top: 10px; }
    </style>
    <script>
        function loadData() {
            fetch('/mcnms/data.json?' + new Date().getTime())
                .then(r => r.json())
                .then(data => {
                    let critical=0, warning=0, normal=0;
                    const tbody = document.getElementById('metricsBody');
                    tbody.innerHTML = '';
                    data.forEach(m => {
                        const row = tbody.insertRow();
                        row.insertCell(0).innerHTML = `<b>${m.service}</b>`;
                        row.insertCell(1).textContent = m.region;
                        row.insertCell(2).textContent = m.protocol;
                        row.insertCell(3).innerHTML = m.rtt ? `<span class="${m.status}">${m.rtt} ms</span>` : 'N/A';
                        row.insertCell(4).innerHTML = `<span class="badge badge-${m.status}">${m.status}</span>`;
                        row.insertCell(5).textContent = m.time;
                        if (m.status === 'critical') critical++;
                        else if (m.status === 'warning') warning++;
                        else if (m.status === 'normal') normal++;
                    });
                    document.getElementById('totalCount').textContent = data.length;
                    document.getElementById('criticalCount').textContent = critical;
                    document.getElementById('warningCount').textContent = warning;
                    document.getElementById('normalCount').textContent = normal;
                    document.getElementById('lastUpdate').textContent = new Date().toLocaleString();
                });
        }
        loadData();
        setInterval(loadData, 10000);
    </script>
</head>
<body>
    <div class="header">
        <h1>📡 MCoreNMS Pro</h1>
        <div>Project ID: MeticulousCoreNMS@42026V1 | Owner: Meticulous Core Global</div>
    </div>
    <div class="nav-links">
        <a href="/mcnms/" class="nav-link">📡 MCoreNMS</a>
        <a href="/smokeping/smokeping.cgi" class="nav-link">📊 Smokeping</a>
    </div>
    <div class="stats">
        <div class="stat-card"><div class="stat-number" id="totalCount">-</div><div>Total</div></div>
        <div class="stat-card"><div class="stat-number" style="color:#dc3545" id="criticalCount">-</div><div>Critical</div></div>
        <div class="stat-card"><div class="stat-number" style="color:#ffc107" id="warningCount">-</div><div>Warning</div></div>
        <div class="stat-card"><div class="stat-number" style="color:#28a745" id="normalCount">-</div><div>Healthy</div></div>
    </div>
    <div class="card">
        <h3>📊 Network Performance Metrics</h3>
        <div class="last-update">Last updated: <span id="lastUpdate">-</span> (auto-refresh every 10s)</div>
        <table id="metricsTable">
            <thead><tr><th>Service</th><th>Region</th><th>Protocol</th><th>RTT</th><th>Status</th><th>Time</th></tr></thead>
            <tbody id="metricsBody"><tr><td colspan="6">Loading... (first collection takes 30-60 secs)</td></tr></tbody>
        </table>
    </div>
    <div class="footer">
        <p>Monitoring: WhatsApp | IMO | BIGO (SG, Mumbai, Dhaka) | Google</p>
        <p>Data collection every 5 minutes | Page auto-refresh every 30 seconds</p>
    </div>
</body>
</html>
HTEOF

# Run collector and setup cron
sudo python3 /opt/mcore-nms/collector.py
(crontab -l 2>/dev/null | grep -v "collector.py"; echo "*/5 * * * * /usr/bin/python3 /opt/mcore-nms/collector.py") | crontab -
sudo chown -R www-data:www-data /var/www/html/mcnms
sudo systemctl restart apache2

echo ""
echo "========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "========================================="
echo "Access: http://157.119.185.254/mcnms/"
echo "========================================="