cat > /tmp/mcnms-final-all.sh << 'EOF'
#!/bin/bash
echo "========================================="
echo "MCoreNMS Pro - COMPLETE ALL FEATURES"
echo "Project ID: MeticulousCoreNMS@42026V1"
echo "========================================="

# Create directories
sudo mkdir -p /opt/mcore-nms
sudo mkdir -p /var/www/html/mcnms
sudo mkdir -p /var/log/mcnms
sudo mkdir -p /var/lib/mcnms/data

# ================================================================
# 1. COMPLETE COLLECTOR WITH ALL SERVICES
# ================================================================
sudo tee /opt/mcore-nms/collector.py << 'PYEOF'
#!/usr/bin/env python3
"""
MCoreNMS Pro - Complete Collector v3.0
Monitors ALL services: WhatsApp, IMO, BIGO, Google, Zoom, Teams
All regions, all protocols
"""

import socket
import time
import json
import os
import subprocess
import sqlite3
from datetime import datetime
from collections import defaultdict

# Configuration
DATA_DIR = '/var/lib/mcnms/data'
DB_PATH = '/var/lib/mcnms/data/metrics.db'
JSON_FILE = '/var/www/html/mcnms/data.json'
HISTORY_FILE = '/var/www/html/mcnms/history.json'
LOG_FILE = '/var/log/mcnms/collector.log'

# Create directories
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs('/var/www/html/mcnms', exist_ok=True)

# ================================================================
# COMPLETE MONITORING TARGETS
# ================================================================

MONITOR_TARGETS = {
    'whatsapp': {
        'name': 'WhatsApp',
        'asn': 'AS32934',
        'company': 'Meta',
        'icon': '💬',
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
        'icon': '📱',
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
        'icon': '🎥',
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
        'icon': '🔍',
        'targets': [
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Global', 'host': 'stun.l.google.com', 'port': 19302, 'protocol': 'udp', 'type': 'STUN'},
            {'region': 'Global', 'host': 'meet.google.com', 'port': 443, 'protocol': 'tcp', 'type': 'WebRTC'},
        ]
    },
    'zoom': {
        'name': 'Zoom',
        'company': 'Zoom Video',
        'icon': '🎬',
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
        'icon': '👥',
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
    """Measure TCP handshake RTT in milliseconds"""
    try:
        start = time.time()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((host, port))
        rtt = (time.time() - start) * 1000
        sock.close()
        return round(rtt, 2)
    except Exception as e:
        return None

def udp_ping(host, port, timeout=3):
    """Measure UDP response time"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        start = time.time()
        sock.sendto(b'PING', (host, port))
        sock.recvfrom(1024)
        rtt = (time.time() - start) * 1000
        sock.close()
        return round(rtt, 2)
    except Exception:
        return None

def get_status(rtt):
    """Determine status based on RTT value"""
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

def init_database():
    """Initialize SQLite database for historical data"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            service TEXT,
            region TEXT,
            host TEXT,
            protocol TEXT,
            rtt REAL,
            status TEXT,
            quality INTEGER
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            service TEXT,
            region TEXT,
            message TEXT,
            severity TEXT,
            acknowledged INTEGER DEFAULT 0
        )
    ''')
    conn.commit()
    conn.close()

def save_to_database(metrics):
    """Save metrics to SQLite database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    for m in metrics:
        cursor.execute('''
            INSERT INTO metrics (timestamp, service, region, host, protocol, rtt, status, quality)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (m['timestamp'], m['service'], m['region'], m['host'], m['protocol'], m['rtt'], m['status'], m['quality']))
    conn.commit()
    conn.close()

def check_and_send_alerts(metrics):
    """Check for critical/warning conditions and log alerts"""
    alerts = []
    for m in metrics:
        if m['status'] == 'critical':
            alerts.append({
                'timestamp': m['timestamp'],
                'service': m['service'],
                'region': m['region'],
                'message': f"CRITICAL: {m['service']} in {m['region']} has {m['rtt']}ms RTT",
                'severity': 'critical'
            })
        elif m['status'] == 'warning':
            alerts.append({
                'timestamp': m['timestamp'],
                'service': m['service'],
                'region': m['region'],
                'message': f"WARNING: {m['service']} in {m['region']} has {m['rtt']}ms RTT",
                'severity': 'warning'
            })
    
    if alerts:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        for alert in alerts:
            cursor.execute('''
                INSERT INTO alerts (timestamp, service, region, message, severity)
                VALUES (?, ?, ?, ?, ?)
            ''', (alert['timestamp'], alert['service'], alert['region'], alert['message'], alert['severity']))
        conn.commit()
        conn.close()
    
    return alerts

# ================================================================
# MAIN COLLECTION
# ================================================================

def collect_all_metrics():
    """Collect all metrics from all targets"""
    init_database()
    
    all_metrics = []
    timestamp = datetime.now().isoformat()
    time_str = datetime.now().strftime('%H:%M:%S')
    date_str = datetime.now().strftime('%Y-%m-%d')
    
    print(f"[{datetime.now()}] Starting collection...")
    
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
                'icon': service_config.get('icon', '📡'),
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
            print(f"  {metric['icon']} {service_config['name']} - {target['region']}: {rtt}ms" if rtt else f"  ❌ {service_config['name']} - {target['region']}: FAILED")
    
    # Calculate summary statistics
    total = len(all_metrics)
    critical = sum(1 for m in all_metrics if m['status'] == 'critical')
    warning = sum(1 for m in all_metrics if m['status'] == 'warning')
    normal = sum(1 for m in all_metrics if m['status'] == 'normal')
    valid_rtts = [m['rtt'] for m in all_metrics if m['rtt']]
    avg_rtt = round(sum(valid_rtts) / len(valid_rtts), 2) if valid_rtts else 0
    min_rtt = min(valid_rtts) if valid_rtts else 0
    max_rtt = max(valid_rtts) if valid_rtts else 0
    
    # Save to database
    save_to_database(all_metrics)
    
    # Check alerts
    alerts = check_and_send_alerts(all_metrics)
    
    # Prepare output data
    output_data = {
        'metrics': all_metrics,
        'summary': {
            'total': total,
            'critical': critical,
            'warning': warning,
            'normal': normal,
            'avg_rtt': avg_rtt,
            'min_rtt': min_rtt,
            'max_rtt': max_rtt,
            'alerts_count': len(alerts),
            'last_update': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'services_count': len(MONITOR_TARGETS),
            'targets_count': total
        },
        'timestamp': timestamp
    }
    
    # Save to JSON file
    with open(JSON_FILE, 'w') as f:
        json.dump(output_data, f, indent=2)
    
    # Update history
    history = []
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, 'r') as f:
                history = json.load(f)
        except:
            history = []
    
    history.append({
        'timestamp': timestamp,
        'avg_rtt': avg_rtt,
        'critical': critical,
        'warning': warning,
        'normal': normal
    })
    
    # Keep last 288 entries (24 hours)
    if len(history) > 288:
        history = history[-288:]
    
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f, indent=2)
    
    # Log to file
    with open(LOG_FILE, 'a') as f:
        f.write(f"{datetime.now()}: Collected {total} metrics | Critical: {critical} | Warning: {warning} | Avg: {avg_rtt}ms\n")
    
    print(f"\n✅ Collection complete: {total} metrics | Critical: {critical} | Warning: {warning} | Avg RTT: {avg_rtt}ms")
    return output_data

if __name__ == '__main__':
    collect_all_metrics()
PYEOF

# ================================================================
# 2. ENHANCED HTML DASHBOARD WITH ALL FEATURES
# ================================================================
sudo tee /var/www/html/mcnms/index.html << 'HTEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>MCoreNMS Pro - 360° Network Visibility Platform</title>
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
            --dark: #343a40;
            --light: #f8f9fa;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            min-height: 100vh;
        }
        
        /* Header */
        .header {
            background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%);
            color: white;
            padding: 25px 30px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        
        .header h1 { font-size: 28px; margin: 0; display: flex; align-items: center; gap: 15px; }
        .project-id { font-family: monospace; font-size: 12px; opacity: 0.8; margin-top: 8px; }
        .owner { font-size: 12px; opacity: 0.7; }
        
        /* Navigation */
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
        
        /* Stats Bar */
        .stats-bar {
            display: flex;
            gap: 20px;
            padding: 20px 30px;
            background: white;
            flex-wrap: wrap;
        }
        
        .stat {
            flex: 1;
            min-width: 140px;
            text-align: center;
            padding: 20px;
            border-radius: 12px;
            background: var(--light);
            transition: transform 0.3s;
            cursor: pointer;
        }
        
        .stat:hover { transform: translateY(-5px); }
        .stat-value { font-size: 36px; font-weight: bold; }
        .stat-label { color: #666; margin-top: 5px; font-size: 14px; }
        .stat-critical { color: var(--danger); }
        .stat-warning { color: var(--warning); }
        .stat-normal { color: var(--success); }
        
        /* Container */
        .container { max-width: 1600px; margin: 30px auto; padding: 0 20px; }
        
        /* Cards */
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
        
        /* Tables */
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: var(--light); color: var(--primary); font-weight: 600; }
        tr:hover { background: var(--light); }
        
        /* Badges */
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
        
        /* RTT Colors */
        .rtt-critical { color: var(--danger); font-weight: bold; }
        .rtt-warning { color: var(--warning); font-weight: bold; }
        .rtt-normal { color: var(--success); }
        
        /* Quality Bar */
        .quality-bar {
            width: 80px;
            height: 6px;
            background: #e0e0e0;
            border-radius: 3px;
            overflow: hidden;
            display: inline-block;
            margin-right: 8px;
        }
        .quality-fill { height: 100%; border-radius: 3px; }
        .quality-high { background: var(--success); }
        .quality-medium { background: var(--warning); }
        .quality-low { background: var(--danger); }
        
        /* Footer */
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
            padding: 10px 15px;
            border-radius: 8px;
            text-align: center;
            margin-bottom: 20px;
            font-size: 14px;
        }
        
        /* Alert Banner */
        .alert-banner {
            background: #fff3cd;
            border-left: 4px solid var(--warning);
            padding: 12px 20px;
            margin-bottom: 20px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
        }
        
        .alert-banner.critical { background: #f8d7da; border-left-color: var(--danger); }
        .alert-banner.warning { background: #fff3cd; border-left-color: var(--warning); }
        
        /* Responsive */
        @media (max-width: 768px) {
            .stats-bar { flex-direction: column; }
            th, td { padding: 8px; font-size: 12px; }
        }
    </style>
    <script>
        let metricsData = { metrics: [], summary: {} };
        let autoRefresh = true;
        
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
                    console.error('Error:', err);
                    document.getElementById('lastUpdateTime').textContent = 'Waiting for data...';
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
            document.getElementById('servicesCount').textContent = summary.services_count || Object.keys(grouped).length;
            
            // Update alert banner
            const alertBanner = document.getElementById('alertBanner');
            if (summary.critical > 0) {
                alertBanner.style.display = 'flex';
                alertBanner.className = 'alert-banner critical';
                alertBanner.innerHTML = `<span>🔴 ${summary.critical} CRITICAL alerts detected!</span>
                                         <button onclick="location.reload()">View Details</button>`;
            } else if (summary.warning > 0) {
                alertBanner.style.display = 'flex';
                alertBanner.className = 'alert-banner warning';
                alertBanner.innerHTML = `<span>🟡 ${summary.warning} WARNING alerts detected</span>
                                         <button onclick="location.reload()">View Details</button>`;
            } else {
                alertBanner.style.display = 'none';
            }
            
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
                const icon = metrics[0]?.icon || '📡';
                
                let tableHtml = `
                    <div class="card">
                        <div class="card-header">
                            <span>${icon} ${service}</span>
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
        
        function toggleAutoRefresh() {
            autoRefresh = !autoRefresh;
            document.getElementById('refreshStatus').textContent = autoRefresh ? 'ON' : 'OFF';
        }
        
        // Load data immediately and every 10 seconds
        loadData();
        setInterval(() => { if (autoRefresh) loadData(); }, 10000);
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
    
    <div id="alertBanner" style="display: none;"></div>
    
    <div class="stats-bar">
        <div class="stat"><div class="stat-value" id="totalCount">-</div><div class="stat-label">Total Monitors</div></div>
        <div class="stat"><div class="stat-value stat-critical" id="criticalCount">-</div><div class="stat-label">Critical</div></div>
        <div class="stat"><div class="stat-value stat-warning" id="warningCount">-</div><div class="stat-label">Warning</div></div>
        <div class="stat"><div class="stat-value stat-normal" id="normalCount">-</div><div class="stat-label">Healthy</div></div>
        <div class="stat"><div class="stat-value" id="avgRtt">-</div><div class="stat-label">Avg RTT</div></div>
        <div class="stat"><div class="stat-value" id="servicesCount">-</div><div class="stat-label">Services</div></div>
    </div>
    
    <div class="container">
        <div class="refresh-info">
            🔄 Auto-refresh: <strong id="refreshStatus">ON</strong> | 
            Data collection every 5 minutes | 
            Last collection: <span id="lastUpdateTimestamp">-</span>
            <button onclick="toggleAutoRefresh()" style="margin-left: 10px; padding: 2px 8px;">Toggle</button>
        </div>
        
        <div id="tablesContainer">
            <div class="card">
                <div class="card-body" style="text-align: center;">
                    <div class="loading-spinner"></div>
                    Loading monitoring data... (first collection takes 30-60 seconds)
                </div>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <p>MCoreNMS Pro v3.0 | Complete 360° Network Visibility Platform</p>
        <p>Monitoring: WhatsApp | IMO | BIGO (10+ regions) | Google | Zoom | Microsoft Teams</p>
        <p>Protocols: TCP | UDP | QUIC | STUN | TURN | WebRTC</p>
        <p>Last updated: <span id="lastUpdateTime">-</span> (auto-refresh every 10 seconds)</p>
    </div>
</body>
</html>
HTEOF

# ================================================================
# 3. TELEGRAM ALERT SCRIPT
# ================================================================
sudo tee /opt/mcore-nms/telegram.py << 'PYEOF'
#!/usr/bin/env python3
import json
import requests
import os
import sqlite3
from datetime import datetime

DB_PATH = '/var/lib/mcnms/data/metrics.db'
LAST_ALERT_FILE = '/var/lib/mcnms/data/last_alert.txt'

# ================================================================
# CONFIGURE YOUR TELEGRAM BOT HERE
# ================================================================
TELEGRAM_BOT_TOKEN = ""  # Get from @BotFather
TELEGRAM_CHAT_ID = ""     # Get from @userinfobot
# ================================================================

def send_telegram(message):
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        try:
            response = requests.post(url, json={
                'chat_id': TELEGRAM_CHAT_ID,
                'text': message,
                'parse_mode': 'HTML'
            })
            return response.ok
        except Exception as e:
            print(f"Telegram error: {e}")
            return False
    return False

def get_critical_alerts():
    """Get recent critical alerts from database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        SELECT timestamp, service, region, message, severity 
        FROM alerts 
        WHERE acknowledged = 0 
        ORDER BY timestamp DESC 
        LIMIT 10
    ''')
    alerts = cursor.fetchall()
    conn.close()
    return alerts

def send_daily_summary():
    """Send daily summary report"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Get today's stats
    today = datetime.now().strftime('%Y-%m-%d')
    cursor.execute('''
        SELECT COUNT(*), AVG(rtt), 
               SUM(CASE WHEN status = 'critical' THEN 1 ELSE 0 END),
               SUM(CASE WHEN status = 'warning' THEN 1 ELSE 0 END)
        FROM metrics 
        WHERE date(timestamp) = date('now')
    ''')
    total, avg_rtt, critical, warning = cursor.fetchone()
    conn.close()
    
    msg = f"📊 <b>MCoreNMS Pro Daily Summary</b>\n"
    msg += f"Date: {today}\n"
    msg += f"━━━━━━━━━━━━━━━━━━━━━━\n"
    msg += f"📡 Total Monitors: {total or 0}\n"
    msg += f"📈 Avg RTT: {round(avg_rtt or 0, 2)}ms\n"
    msg += f"🔴 Critical: {critical or 0}\n"
    msg += f"🟡 Warning: {warning or 0}\n"
    msg += f"━━━━━━━━━━━━━━━━━━━━━━\n"
    msg += f"Dashboard: http://157.119.185.254/mcnms/"
    
    send_telegram(msg)

def check_and_alert():
    """Check for new critical alerts"""
    alerts = get_critical_alerts()
    if alerts:
        for alert in alerts:
            timestamp, service, region, message, severity = alert
            emoji = "🔴" if severity == "critical" else "🟡"
            msg = f"{emoji} <b>ALERT: {service}</b>\n"
            msg += f"Region: {region}\n"
            msg += f"Time: {timestamp}\n"
            msg += f"Details: {message}\n"
            send_telegram(msg)

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == 'summary':
        send_daily_summary()
    else:
        check_and_alert()
PYEOF

# ================================================================
# 4. SETUP PERMISSIONS AND CRON JOBS
# ================================================================
sudo chmod +x /opt/mcore-nms/collector.py
sudo chmod +x /opt/mcore-nms/telegram.py

# Run initial collection
echo "Running initial data collection..."
sudo python3 /opt/mcore-nms/collector.py

# Setup cron jobs
(crontab -l 2>/dev/null | grep -v "mcore-nms"; 
 echo "# MCoreNMS Pro Cron Jobs"
 echo "*/5 * * * * /usr/bin/python3 /opt/mcore-nms/collector.py >> /var/log/mcnms/cron.log 2>&1"
 echo "*/5 * * * * /usr/bin/python3 /opt/mcore-nms/telegram.py >> /var/log/mcnms/telegram.log 2>&1"
 echo "0 8 * * * /usr/bin/python3 /opt/mcore-nms/telegram.py summary >> /var/log/mcnms/summary.log 2>&1"
) | crontab -

# Set permissions
sudo chown -R www-data:www-data /var/www/html/mcnms
sudo chown -R www-data:www-data /var/lib/mcnms
sudo chmod -R 755 /var/www/html/mcnms
sudo chmod -R 755 /var/lib/mcnms

# Restart Apache
sudo systemctl restart apache2

echo ""
echo "========================================="
echo "✅ MCoreNMS Pro - COMPLETE DEPLOYMENT!"
echo "========================================="
echo ""
echo "📡 Dashboard: http://157.119.185.254/mcnms/"
echo "📊 Smokeping: http://157.119.185.254/smokeping/smokeping.cgi"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MONITORING COVERAGE:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  💬 WhatsApp     - HTTPS, XMPP, STUN, TURN"
echo "  📱 IMO          - HTTPS, STUN, API"
echo "  🎥 BIGO Live    - 10+ regions (SG, Mumbai, Dhaka, Riyadh, Doha, Dubai, Frankfurt, Amsterdam)"
echo "  🔍 Google       - HTTPS, QUIC, STUN, WebRTC"
echo "  🎬 Zoom         - HTTPS, UDP Media"
echo "  👥 Teams        - HTTPS, STUN"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "FEATURES ENABLED:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Real-time RTT monitoring"
echo "  ✅ Quality score (0-100%)"
echo "  ✅ Critical/Warning alerts"
echo "  ✅ Historical data (SQLite)"
echo "  ✅ Daily summary reports"
echo "  ✅ Auto-refresh dashboard"
echo "  ✅ Professional UI/UX"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TO ENABLE TELEGRAM ALERTS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  sudo nano /opt/mcore-nms/telegram.py"
echo "  Add your TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
echo ""
echo "Then test: sudo python3 /opt/mcore-nms/telegram.py summary"
echo "========================================="
EOF

# Execute the complete deployment
bash /tmp/mcnms-final-all.sh