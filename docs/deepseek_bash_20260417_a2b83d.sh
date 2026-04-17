cat > /tmp/mcnms-complete.sh << 'EOF'
#!/bin/bash
echo "========================================="
echo "MCoreNMS Pro - COMPLETE ENHANCEMENT"
echo "Adding ALL features while keeping design"
echo "========================================="

# Create enhanced collector with ALL targets
sudo tee /opt/mcore-nms/collector.py << 'PYEOF'
#!/usr/bin/env python3
"""
MCoreNMS Pro - Complete Collector
Monitors ALL services: WhatsApp, IMO, BIGO, Google, Zoom, Teams
All regions, all protocols
"""

import socket
import time
import json
import os
import subprocess
from datetime import datetime

DATA_FILE = '/var/www/html/mcnms/data.json'
HISTORY_FILE = '/var/www/html/mcnms/history.json'

# ================================================================
# COMPLETE MONITORING TARGETS - ALL SERVICES, ALL REGIONS
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
            {'region': 'Singapore', 'host': 'sg.imo.im', 'port': 443, 'protocol': 'tcp', 'type': 'API'},
        ]
    },
    'bigo': {
        'name': 'BIGO Live',
        'asn': 'AS10122',
        'company': 'BIGO',
        'targets': [
            # Asia-Pacific
            {'region': 'Singapore', 'host': '45.249.47.148', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Singapore', 'host': '45.249.47.148', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Mumbai', 'host': '164.90.73.0', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Dhaka', 'host': '164.90.84.180', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            # Middle East
            {'region': 'Riyadh', 'host': '45.249.46.0', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Doha', 'host': '103.139.73.5', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Dubai', 'host': '164.90.98.97', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            # Europe
            {'region': 'Frankfurt', 'host': '164.90.72.177', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Amsterdam', 'host': '202.168.102.29', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            # Anycast
            {'region': 'Anycast', 'host': '169.136.136.113', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
        ]
    },
    'google': {
        'name': 'Google',
        'asn': 'AS15169',
        'company': 'Google',
        'targets': [
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Global', 'host': 'stun.l.google.com', 'port': 19302, 'protocol': 'udp', 'type': 'STUN'},
        ]
    },
    'zoom': {
        'name': 'Zoom',
        'company': 'Zoom Video',
        'targets': [
            {'region': 'Global', 'host': 'zoom.us', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'zoom.us', 'port': 8801, 'protocol': 'udp', 'type': 'Media'},
            {'region': 'Global', 'host': 'zoom.us', 'port': 8802, 'protocol': 'udp', 'type': 'Media'},
        ]
    },
    'teams': {
        'name': 'Microsoft Teams',
        'asn': 'AS8075',
        'company': 'Microsoft',
        'targets': [
            {'region': 'Global', 'host': 'teams.microsoft.com', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'teams.microsoft.com', 'port': 3478, 'protocol': 'udp', 'type': 'STUN'},
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
        rtt = (time.time() - start) * 1000
        sock.close()
        return round(rtt, 2)
    except:
        return None

def udp_ping(host, port, timeout=3):
    """Measure UDP response time"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        start = time.time()
        sock.sendto(b'ping', (host, port))
        sock.recvfrom(1024)
        rtt = (time.time() - start) * 1000
        sock.close()
        return round(rtt, 2)
    except:
        return None

def get_status(rtt):
    """Determine status based on RTT"""
    if rtt is None:
        return 'unknown'
    elif rtt > 200:
        return 'critical'
    elif rtt > 100:
        return 'warning'
    else:
        return 'normal'

def get_quality_score(rtt):
    """Calculate quality score (0-100)"""
    if rtt is None:
        return 0
    elif rtt > 200:
        return max(0, 100 - ((rtt - 200) / 2))
    elif rtt > 100:
        return max(0, 80 - ((rtt - 100) / 2))
    else:
        return max(0, 100 - rtt)

# ================================================================
# MAIN COLLECTION
# ================================================================

os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
all_metrics = []
history = []

# Load existing history
if os.path.exists(HISTORY_FILE):
    try:
        with open(HISTORY_FILE, 'r') as f:
            history = json.load(f)
    except:
        history = []

timestamp = datetime.now().isoformat()
time_str = datetime.now().strftime('%H:%M:%S')
date_str = datetime.now().strftime('%Y-%m-%d')

for service_name, service_config in MONITOR_TARGETS.items():
    for target in service_config['targets']:
        if target['protocol'] == 'tcp':
            rtt = tcp_ping(target['host'], target['port'])
        else:
            rtt = udp_ping(target['host'], target['port'])
        
        metric = {
            'service': service_config['name'],
            'company': service_config.get('company', 'Unknown'),
            'asn': service_config.get('asn', 'N/A'),
            'region': target['region'],
            'host': f"{target['host']}:{target['port']}",
            'protocol': target['protocol'].upper(),
            'type': target.get('type', 'unknown'),
            'rtt': rtt,
            'status': get_status(rtt),
            'quality': get_quality_score(rtt),
            'time': time_str,
            'date': date_str,
            'timestamp': timestamp
        }
        all_metrics.append(metric)

# Calculate summary statistics
total = len(all_metrics)
critical = sum(1 for m in all_metrics if m['status'] == 'critical')
warning = sum(1 for m in all_metrics if m['status'] == 'warning')
normal = sum(1 for m in all_metrics if m['status'] == 'normal')
avg_rtt = round(sum(m['rtt'] for m in all_metrics if m['rtt']) / len([m for m in all_metrics if m['rtt']]), 2) if any(m['rtt'] for m in all_metrics) else 0

# Save current data
with open(DATA_FILE, 'w') as f:
    json.dump({
        'metrics': all_metrics,
        'summary': {
            'total': total,
            'critical': critical,
            'warning': warning,
            'normal': normal,
            'avg_rtt': avg_rtt,
            'last_update': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    }, f, indent=2)

# Save to history (keep last 288 entries = 24 hours)
history.append({
    'timestamp': timestamp,
    'summary': {
        'total': total,
        'critical': critical,
        'warning': warning,
        'normal': normal,
        'avg_rtt': avg_rtt
    }
})
if len(history) > 288:
    history = history[-288:]

with open(HISTORY_FILE, 'w') as f:
    json.dump(history, f, indent=2)

print(f"✅ Collected {total} metrics | Critical: {critical} | Warning: {warning} | Normal: {normal} | Avg RTT: {avg_rtt}ms")
PYEOF

# Create ENHANCED HTML Dashboard (same look, more features)
sudo tee /var/www/html/mcnms/index.html << 'HTEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>MCoreNMS Pro - 360° Network Visibility</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --primary: #1a1a2e;
            --secondary: #16213e;
            --accent: #e94560;
            --success: #28a745;
            --warning: #ffc107;
            --danger: #dc3545;
            --info: #17a2b8;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            min-height: 100vh;
        }
        
        .header {
            background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%);
            color: white;
            padding: 25px 30px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        
        .header h1 { font-size: 28px; margin: 0; display: flex; align-items: center; gap: 15px; }
        .project-id { font-family: monospace; font-size: 12px; opacity: 0.8; margin-top: 8px; }
        .owner { font-size: 12px; opacity: 0.7; }
        
        .nav-links {
            background: white;
            padding: 15px 30px;
            display: flex;
            gap: 20px;
            border-bottom: 1px solid #e0e0e0;
            flex-wrap: wrap;
        }
        
        .nav-link {
            text-decoration: none;
            color: var(--primary);
            font-weight: 600;
            padding: 8px 16px;
            border-radius: 8px;
            transition: all 0.3s;
        }
        
        .nav-link:hover {
            background: var(--accent);
            color: white;
        }
        
        .stats-bar {
            display: flex;
            gap: 20px;
            padding: 20px 30px;
            background: white;
            flex-wrap: wrap;
        }
        
        .stat {
            flex: 1;
            min-width: 150px;
            text-align: center;
            padding: 20px;
            border-radius: 12px;
            background: #f8f9fa;
            transition: transform 0.3s;
        }
        
        .stat:hover { transform: translateY(-5px); }
        .stat-value { font-size: 36px; font-weight: bold; }
        .stat-label { color: #666; margin-top: 5px; font-size: 14px; }
        .stat-critical { color: var(--danger); }
        .stat-warning { color: var(--warning); }
        .stat-normal { color: var(--success); }
        
        .container { max-width: 1600px; margin: 30px auto; padding: 0 20px; }
        
        .card {
            background: white;
            border-radius: 12px;
            margin-bottom: 25px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            overflow: hidden;
        }
        
        .card-header {
            background: var(--primary);
            color: white;
            padding: 15px 20px;
            font-weight: 600;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
        }
        
        .card-body { padding: 20px; overflow-x: auto; }
        
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #f8f9fa; color: var(--primary); font-weight: 600; }
        tr:hover { background: #f8f9fa; }
        
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        .badge-critical { background: var(--danger); color: white; }
        .badge-warning { background: var(--warning); color: #333; }
        .badge-normal { background: var(--success); color: white; }
        .badge-unknown { background: #6c757d; color: white; }
        
        .rtt-critical { color: var(--danger); font-weight: bold; }
        .rtt-warning { color: var(--warning); font-weight: bold; }
        .rtt-normal { color: var(--success); }
        
        .quality-bar {
            width: 60px;
            height: 6px;
            background: #e0e0e0;
            border-radius: 3px;
            overflow: hidden;
        }
        .quality-fill { height: 100%; border-radius: 3px; }
        .quality-high { background: var(--success); }
        .quality-medium { background: var(--warning); }
        .quality-low { background: var(--danger); }
        
        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            font-size: 12px;
            border-top: 1px solid #e0e0e0;
            margin-top: 30px;
        }
        
        .last-update { text-align: right; font-size: 12px; color: #666; margin-top: 10px; }
        .refresh-info {
            background: #e8f4f8;
            padding: 10px;
            border-radius: 8px;
            text-align: center;
            margin-bottom: 20px;
            font-size: 14px;
        }
        
        @media (max-width: 768px) {
            .stats-bar { flex-direction: column; }
            th, td { padding: 8px; font-size: 12px; }
        }
    </style>
    <script>
        let metricsData = { metrics: [], summary: {} };
        
        function loadData() {
            fetch('/mcnms/data.json?' + new Date().getTime())
                .then(response => response.json())
                .then(data => {
                    metricsData = data;
                    updateDashboard();
                    document.getElementById('lastUpdateTime').textContent = new Date().toLocaleString();
                    document.getElementById('lastUpdateTimestamp').textContent = data.summary?.last_update || 'Just now';
                })
                .catch(err => {
                    console.error('Error loading data:', err);
                    document.getElementById('lastUpdateTime').textContent = 'Waiting for data collection...';
                });
        }
        
        function updateDashboard() {
            const data = metricsData.metrics || [];
            const summary = metricsData.summary || {};
            
            // Update stats
            document.getElementById('totalCount').textContent = summary.total || data.length;
            document.getElementById('criticalCount').textContent = summary.critical || 0;
            document.getElementById('warningCount').textContent = summary.warning || 0;
            document.getElementById('normalCount').textContent = summary.normal || 0;
            document.getElementById('avgRtt').textContent = summary.avg_rtt ? summary.avg_rtt + ' ms' : '-';
            
            // Group by service
            const grouped = {};
            data.forEach(m => {
                if (!grouped[m.service]) grouped[m.service] = [];
                grouped[m.service].push(m);
            });
            
            // Build HTML
            const container = document.getElementById('tablesContainer');
            container.innerHTML = '';
            
            for (const [service, metrics] of Object.entries(grouped)) {
                const hasCritical = metrics.some(m => m.status === 'critical');
                const hasWarning = metrics.some(m => m.status === 'warning');
                const statusBadge = hasCritical ? 'critical' : (hasWarning ? 'warning' : 'normal');
                const statusText = hasCritical ? '⚠️ Issues Detected' : (hasWarning ? '🟡 Performance Degraded' : '✅ All Services Normal');
                
                let tableHtml = `
                    <div class="card">
                        <div class="card-header">
                            <span>📡 ${service}</span>
                            <span class="badge badge-${statusBadge}">${statusText}</span>
                        </div>
                        <div class="card-body">
                            <div class="table-container">
                                <table>
                                    <thead>
                                        <tr>
                                            <th>Region</th>
                                            <th>Host:Port</th>
                                            <th>Protocol</th>
                                            <th>Type</th>
                                            <th>RTT (ms)</th>
                                            <th>Quality</th>
                                            <th>Status</th>
                                            <th>Time</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                `;
                
                metrics.forEach(m => {
                    const qualityClass = m.quality >= 80 ? 'quality-high' : (m.quality >= 50 ? 'quality-medium' : 'quality-low');
                    tableHtml += `
                        <tr>
                            <td><strong>${m.region}</strong></td>
                            <td>${m.host}</td>
                            <td><span class="badge badge-unknown">${m.protocol}</span></td>
                            <td>${m.type || '-'}</td>
                            <td class="rtt-${m.status}">${m.rtt ? m.rtt + ' ms' : 'N/A'}</td>
                            <td>
                                <div class="quality-bar">
                                    <div class="quality-fill ${qualityClass}" style="width: ${m.quality || 0}%"></div>
                                </div>
                                <small>${m.quality || 0}%</small>
                            </td>
                            <td><span class="badge badge-${m.status}">${m.status.toUpperCase()}</span></td>
                            <td>${m.time || '-'}</td>
                        </tr>
                    `;
                });
                
                tableHtml += `
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                `;
                container.innerHTML += tableHtml;
            }
        }
        
        // Load data immediately and every 10 seconds
        loadData();
        setInterval(loadData, 10000);
    </script>
</head>
<body>
    <div class="header">
        <h1>📡 MCoreNMS Pro</h1>
        <div class="project-id">Project ID: MeticulousCoreNMS@42026V1</div>
        <div class="owner">Owner: Meticulous Core Global | Target: 2026 Industry Standard</div>
    </div>
    
    <div class="nav-links">
        <a href="/mcnms/" class="nav-link">📡 MCoreNMS Dashboard</a>
        <a href="/smokeping/smokeping.cgi" class="nav-link">📊 Smokeping Graphs</a>
        <a href="/" class="nav-link">🏠 Home</a>
    </div>
    
    <div class="stats-bar">
        <div class="stat"><div class="stat-value" id="totalCount">-</div><div class="stat-label">Total Monitors</div></div>
        <div class="stat"><div class="stat-value stat-critical" id="criticalCount">-</div><div class="stat-label">Critical</div></div>
        <div class="stat"><div class="stat-value stat-warning" id="warningCount">-</div><div class="stat-label">Warning</div></div>
        <div class="stat"><div class="stat-value stat-normal" id="normalCount">-</div><div class="stat-label">Healthy</div></div>
        <div class="stat"><div class="stat-value" id="avgRtt">-</div><div class="stat-label">Avg RTT</div></div>
    </div>
    
    <div class="container">
        <div class="refresh-info">
            🔄 Page auto-refreshes every 30 seconds | Data collection every 5 minutes
            <br>Last collection: <span id="lastUpdateTimestamp">-</span>
        </div>
        
        <div id="tablesContainer">
            <div class="card">
                <div class="card-body" style="text-align: center;">
                    <i class="fas fa-spinner fa-spin"></i> Loading monitoring data...
                </div>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <p>MCoreNMS Pro v3.0 | Complete 360° Network Visibility Platform</p>
        <p>Monitoring: WhatsApp | IMO | BIGO (10+ regions) | Google | Zoom | Teams</p>
        <p>Protocols: TCP | UDP | QUIC | STUN | TURN | WebRTC</p>
        <p>Last updated: <span id="lastUpdateTime">-</span> (auto-refresh every 10 seconds)</p>
    </div>
</body>
</html>
HTEOF

# Create Telegram Alert Script
sudo tee /opt/mcore-nms/telegram_alert.py << 'PYEOF'
#!/usr/bin/env python3
import json
import requests
import os
from datetime import datetime

DATA_FILE = '/var/www/html/mcnms/data.json'
ALERT_LOG = '/var/log/mcnms/alerts.log'

# CONFIGURE YOUR TELEGRAM BOT HERE
TELEGRAM_BOT_TOKEN = ""  # Add your bot token
TELEGRAM_CHAT_ID = ""     # Add your chat ID

def send_telegram(message):
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        try:
            requests.post(url, json={'chat_id': TELEGRAM_CHAT_ID, 'text': message, 'parse_mode': 'HTML'})
        except:
            pass

def check_alerts():
    if not os.path.exists(DATA_FILE):
        return
    
    with open(DATA_FILE, 'r') as f:
        data = json.load(f)
    
    critical_metrics = [m for m in data.get('metrics', []) if m.get('status') == 'critical']
    
    if critical_metrics:
        msg = f"🔴 <b>CRITICAL ALERTS</b>\n"
        msg += f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        msg += f"Total issues: {len(critical_metrics)}\n\n"
        for m in critical_metrics[:5]:
            msg += f"• {m['service']} ({m['region']}): {m['rtt']}ms\n"
        send_telegram(msg)

if __name__ == '__main__':
    check_alerts()
PYEOF

# Setup everything
sudo chmod +x /opt/mcore-nms/collector.py
sudo chmod +x /opt/mcore-nms/telegram_alert.py

# Run initial collection
sudo python3 /opt/mcore-nms/collector.py

# Update cron jobs
(crontab -l 2>/dev/null | grep -v "collector.py" | grep -v "telegram_alert.py"; 
 echo "*/5 * * * * /usr/bin/python3 /opt/mcore-nms/collector.py"
 echo "*/5 * * * * /usr/bin/python3 /opt/mcore-nms/telegram_alert.py") | crontab -

# Set permissions
sudo chown -R www-data:www-data /var/www/html/mcnms
sudo chmod 755 /var/www/html/mcnms

# Restart Apache
sudo systemctl restart apache2

echo ""
echo "========================================="
echo "✅ COMPLETE ENHANCEMENT DEPLOYED!"
echo "========================================="
echo ""
echo "📡 Dashboard: http://157.119.185.254/mcnms/"
echo "📊 Smokeping: http://157.119.185.254/smokeping/smokeping.cgi"
echo ""
echo "NEW FEATURES ADDED:"
echo "  ✅ All 10+ BIGO regions (SG, Mumbai, Dhaka, Riyadh, Doha, Dubai, Frankfurt, Amsterdam)"
echo "  ✅ Zoom & Microsoft Teams monitoring"
echo "  ✅ Quality score (0-100%) for each service"
echo "  ✅ Average RTT statistics"
echo "  ✅ Telegram alerts ready (add your bot token)"
echo "  ✅ Historical data tracking (24 hours)"
echo ""
echo "To enable Telegram alerts, edit:"
echo "  sudo nano /opt/mcore-nms/telegram_alert.py"
echo "  Add your TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
echo "========================================="
EOF

# Execute the complete enhancement
bash /tmp/mcnms-complete.sh