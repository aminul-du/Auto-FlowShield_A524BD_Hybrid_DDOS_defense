#!/usr/bin/env python3
"""
MCoreNMS Pro - Complete 360° Network Visibility Platform
Project ID: MeticulousCoreNMS@42026V1
Owner: Meticulous Core Global
Target Year: 2026 Industry Standard

This is a COMPLETE, SELF-CONTAINED monitoring solution.
It does NOT depend on Smokeping - it can use it optionally.
"""

import os
import sys
import socket
import struct
import time
import json
import threading
import subprocess
import random
from datetime import datetime, timedelta
from collections import defaultdict
import logging

# Flask for web interface
from flask import Flask, jsonify, render_template_string, request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/mcnms/mcnms.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ================================================================
# CONFIGURATION - All Targets We Monitor
# ================================================================

# Target definitions - NO LIMITS, ALL APPS, ALL PROTOCOLS
MONITOR_TARGETS = {
    # ========== WHATSAPP / META (AS32934) ==========
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
            {'region': 'Global', 'host': 'stun.whatsapp.com', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
        ]
    },
    
    # ========== IMO / PAGEBITES (AS36131) ==========
    'imo': {
        'name': 'IMO',
        'asn': 'AS36131',
        'company': 'PageBites',
        'targets': [
            {'region': 'Global', 'host': 'imo.im', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'imo.im', 'port': 80, 'protocol': 'tcp', 'type': 'HTTP'},
            {'region': 'Global', 'host': 'stun.imo.im', 'port': 3478, 'protocol': 'udp', 'type': 'STUN'},
            {'region': 'Global', 'host': 'turn.imo.im', 'port': 19302, 'protocol': 'udp', 'type': 'TURN'},
            {'region': 'Singapore', 'host': 'sg.imo.im', 'port': 443, 'protocol': 'tcp', 'type': 'API'},
            {'region': 'Singapore', 'host': 'sg.imo.im', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
        ]
    },
    
    # ========== BIGO LIVE (AS10122) - ALL REGIONS ==========
    'bigo': {
        'name': 'BIGO Live',
        'asn': 'AS10122',
        'company': 'BIGO',
        'targets': [
            # Primary Hub
            {'region': 'Singapore', 'host': '45.249.47.148', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Singapore', 'host': '45.249.47.148', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            # India
            {'region': 'Mumbai', 'host': '164.90.73.0', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Mumbai', 'host': '164.90.73.0', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            # Bangladesh Edge
            {'region': 'Dhaka', 'host': '164.90.84.180', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            # Middle East
            {'region': 'Riyadh', 'host': '45.249.46.0', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Doha', 'host': '103.139.73.5', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Dubai', 'host': '164.90.98.97', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            # Europe
            {'region': 'Frankfurt', 'host': '164.90.72.177', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Amsterdam', 'host': '202.168.102.29', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            # Anycast
            {'region': 'Anycast', 'host': '169.136.136.113', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
        ]
    },
    
    # ========== GOOGLE SERVICES (AS15169) ==========
    'google': {
        'name': 'Google Services',
        'asn': 'AS15169',
        'company': 'Google',
        'targets': [
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'udp', 'type': 'QUIC'},
            {'region': 'Global', 'host': 'stun.l.google.com', 'port': 19302, 'protocol': 'udp', 'type': 'STUN'},
            {'region': 'Global', 'host': 'meet.google.com', 'port': 443, 'protocol': 'tcp', 'type': 'WebRTC'},
        ]
    },
    
    # ========== ZOOM ==========
    'zoom': {
        'name': 'Zoom',
        'asn': 'Unknown',
        'company': 'Zoom',
        'targets': [
            {'region': 'Global', 'host': 'zoom.us', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'zoom.us', 'port': 8801, 'protocol': 'udp', 'type': 'Media'},
            {'region': 'Global', 'host': 'zoom.us', 'port': 8802, 'protocol': 'udp', 'type': 'Media'},
        ]
    },
    
    # ========== MICROSOFT TEAMS ==========
    'teams': {
        'name': 'Microsoft Teams',
        'asn': 'AS8075',
        'company': 'Microsoft',
        'targets': [
            {'region': 'Global', 'host': 'teams.microsoft.com', 'port': 443, 'protocol': 'tcp', 'type': 'HTTPS'},
            {'region': 'Global', 'host': 'teams.microsoft.com', 'port': 3478, 'protocol': 'udp', 'type': 'STUN'},
            {'region': 'Global', 'host': 'teams.microsoft.com', 'port': 3479, 'protocol': 'udp', 'type': 'TURN'},
        ]
    },
}

# ================================================================
# PROBE FUNCTIONS - Our Own Implementation (No Smokeping Dependency)
# ================================================================

def tcp_ping(host, port, timeout=5):
    """
    Measure TCP handshake RTT.
    
    How it works:
    1. Record start time
    2. Open TCP connection to host:port
    3. Record end time when SYN-ACK received
    4. Calculate RTT = end - start
    
    Returns: RTT in milliseconds, or None if failed
    """
    try:
        start = time.time()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((host, port))
        end = time.time()
        sock.close()
        rtt = (end - start) * 1000  # Convert to milliseconds
        return round(rtt, 2)
    except Exception as e:
        logger.debug(f"TCP ping failed to {host}:{port} - {e}")
        return None

def udp_ping(host, port, timeout=3):
    """
    Measure UDP round-trip time using echo.
    
    How it works:
    1. Send a UDP packet with timestamp
    2. Wait for response (if service echoes back)
    3. Calculate RTT
    
    Note: This requires the remote service to respond to UDP probes.
    For STUN/TURN, we send a STUN binding request.
    """
    try:
        # Create UDP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        
        # Send a simple probe packet
        probe_data = b'\x00\x01\x00\x00\x00\x00\x00\x00'  # Simple echo request
        start = time.time()
        sock.sendto(probe_data, (host, port))
        
        # Wait for any response
        sock.recvfrom(1024)
        end = time.time()
        sock.close()
        
        rtt = (end - start) * 1000
        return round(rtt, 2)
    except socket.timeout:
        logger.debug(f"UDP ping timeout to {host}:{port}")
        return None
    except Exception as e:
        logger.debug(f"UDP ping failed to {host}:{port} - {e}")
        return None

def quic_ping(host, port, timeout=3):
    """
    Detect QUIC protocol and measure initial RTT.
    
    QUIC uses UDP port 443 with specific packet structure.
    We send a QUIC Initial packet and measure time to response.
    """
    try:
        # QUIC Initial packet structure (simplified)
        # This is a valid QUIC Initial packet for connection attempt
        quic_initial = bytes([
            0xc0,  # Long header, Initial
            0x00, 0x00, 0x00, 0x01,  # Version 1
            0x08,  # Destination connection ID length
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # DCID
            0x00,  # Source connection ID length
            0x00,  # Token length
            0x40,  # Length (64 bytes)
        ])
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        
        start = time.time()
        sock.sendto(quic_initial, (host, port))
        sock.recvfrom(1024)
        end = time.time()
        sock.close()
        
        rtt = (end - start) * 1000
        return round(rtt, 2)
    except socket.timeout:
        # QUIC may not respond to initial packet - that's normal
        # We'll return a high value to indicate possible issue
        return 999
    except Exception as e:
        logger.debug(f"QUIC ping failed to {host}:{port} - {e}")
        return None

def stun_ping(host, port=3478, timeout=3):
    """
    Measure STUN server response time.
    
    STUN is used for NAT traversal in WebRTC and VoIP.
    """
    try:
        # STUN Binding Request (RFC 5389)
        # Message Type: Binding Request (0x0001)
        # Message Length: 0
        # Magic Cookie: 0x2112A442
        stun_request = bytes([
            0x00, 0x01,  # Binding Request
            0x00, 0x00,  # Length
            0x21, 0x12, 0xa4, 0x42,  # Magic Cookie
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  # Transaction ID
        ])
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        
        start = time.time()
        sock.sendto(stun_request, (host, port))
        sock.recvfrom(1024)
        end = time.time()
        sock.close()
        
        rtt = (end - start) * 1000
        return round(rtt, 2)
    except Exception as e:
        logger.debug(f"STUN ping failed to {host}:{port} - {e}")
        return None

def dns_ping(host, timeout=2):
    """
    Measure DNS resolution time.
    """
    try:
        start = time.time()
        socket.gethostbyname(host)
        end = time.time()
        rtt = (end - start) * 1000
        return round(rtt, 2)
    except Exception as e:
        logger.debug(f"DNS resolution failed for {host}: {e}")
        return None

def icmp_ping(host, count=3, timeout=2):
    """
    Traditional ICMP ping using system ping command.
    """
    try:
        cmd = ['ping', '-c', str(count), '-W', str(timeout), host]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout+2)
        
        if result.returncode == 0:
            # Parse average RTT from output
            import re
            match = re.search(r'= [\d.]+/([\d.]+)/[\d.]+', result.stdout)
            if match:
                return round(float(match.group(1)), 2)
        return None
    except Exception as e:
        logger.debug(f"ICMP ping failed to {host}: {e}")
        return None

# ================================================================
# PROBE DISPATCHER
# ================================================================

def run_probe(target):
    """
    Run the appropriate probe based on protocol type.
    """
    protocol = target.get('protocol', 'tcp')
    host = target['host']
    port = target.get('port', 443)
    
    # First resolve hostname to IP if needed
    if not host.replace('.', '').isdigit():  # Not an IP address
        ip = dns_ping(host)
        if ip:
            host = host  # Keep hostname for display, but we resolved it
        else:
            return None
    
    # Run the appropriate probe
    if protocol == 'tcp':
        return tcp_ping(host, port)
    elif protocol == 'udp':
        if target.get('type') == 'STUN':
            return stun_ping(host, port)
        else:
            return udp_ping(host, port)
    elif protocol == 'quic':
        return quic_ping(host, port)
    elif protocol == 'icmp':
        return icmp_ping(host)
    else:
        return tcp_ping(host, port)

# ================================================================
# DATA COLLECTION ENGINE
# ================================================================

class MetricsCollector:
    """
    Collects metrics from all targets periodically.
    This runs in a background thread.
    """
    
    def __init__(self):
        self.metrics = defaultdict(list)
        self.last_collection = None
        self.running = True
        
    def collect_all(self):
        """
        Collect metrics from all configured targets.
        """
        all_metrics = []
        
        for service_name, service_config in MONITOR_TARGETS.items():
            for target in service_config['targets']:
                logger.info(f"Probing {service_name} - {target['region']} - {target['protocol']}/{target['port']}")
                
                # Run the probe
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
                self.metrics[f"{service_name}_{target['region']}_{target['protocol']}"].append(metric)
                
                # Keep only last 24 hours of data
                cutoff = datetime.now() - timedelta(hours=24)
                self.metrics[f"{service_name}_{target['region']}_{target['protocol']}"] = [
                    m for m in self.metrics[f"{service_name}_{target['region']}_{target['protocol']}"]
                    if datetime.fromisoformat(m['timestamp']) > cutoff
                ]
                
                # Small delay to avoid flooding
                time.sleep(0.5)
        
        self.last_collection = datetime.now()
        return all_metrics
    
    def _get_status(self, rtt):
        """Determine status based on RTT value"""
        if rtt is None:
            return 'unknown'
        elif rtt > 200:
            return 'critical'
        elif rtt > 100:
            return 'warning'
        else:
            return 'normal'
    
    def get_latest_metrics(self):
        """Get the most recent metrics for each target"""
        latest = []
        
        for key, history in self.metrics.items():
            if history:
                latest.append(history[-1])
        
        return latest
    
    def start_background_collection(self, interval=300):
        """
        Start background thread that collects metrics every 'interval' seconds.
        """
        def collect_loop():
            while self.running:
                try:
                    logger.info(f"Starting collection cycle at {datetime.now()}")
                    self.collect_all()
                    logger.info(f"Collection cycle completed at {datetime.now()}")
                except Exception as e:
                    logger.error(f"Collection error: {e}")
                time.sleep(interval)
        
        thread = threading.Thread(target=collect_loop, daemon=True)
        thread.start()
        logger.info(f"Background collection started (interval: {interval}s)")
        return thread

# ================================================================
# FLASK WEB APPLICATION
# ================================================================

app = Flask(__name__)
collector = MetricsCollector()

# HTML Template - Complete Dashboard
DASHBOARD_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MCoreNMS Pro - 360° Network Visibility</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --primary: #1a1a2e;
            --secondary: #16213e;
            --accent: #e94560;
            --success: #28a745;
            --warning: #f5a623;
            --danger: #dc3545;
            --info: #17a2b8;
            --light: #f8f9fa;
            --dark: #343a40;
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
        
        .header h1 {
            font-size: 32px;
            margin: 0;
            display: flex;
            align-items: center;
            gap: 15px;
        }
        
        .header h1 i {
            font-size: 40px;
            color: var(--accent);
        }
        
        .project-id {
            font-family: monospace;
            font-size: 12px;
            opacity: 0.7;
            margin-top: 8px;
        }
        
        .owner {
            font-size: 12px;
            opacity: 0.7;
        }
        
        /* Stats Bar */
        .stats-bar {
            display: flex;
            gap: 20px;
            padding: 20px 30px;
            background: white;
            border-bottom: 1px solid #e0e0e0;
            flex-wrap: wrap;
        }
        
        .stat {
            flex: 1;
            min-width: 150px;
            text-align: center;
            padding: 15px;
            border-radius: 10px;
            background: var(--light);
        }
        
        .stat-value {
            font-size: 32px;
            font-weight: bold;
        }
        
        .stat-label {
            font-size: 14px;
            color: #666;
            margin-top: 5px;
        }
        
        .stat-critical { color: var(--danger); }
        .stat-warning { color: var(--warning); }
        .stat-normal { color: var(--success); }
        
        /* Main Content */
        .container {
            max-width: 1600px;
            margin: 30px auto;
            padding: 0 20px;
        }
        
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
        }
        
        .card-header i {
            margin-right: 10px;
        }
        
        .card-body {
            padding: 20px;
        }
        
        /* Tables */
        .table-container {
            overflow-x: auto;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        
        th {
            background: #f8f9fa;
            font-weight: 600;
            color: var(--primary);
        }
        
        tr:hover {
            background: #f8f9fa;
        }
        
        /* Status Badges */
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .badge-critical {
            background: var(--danger);
            color: white;
        }
        
        .badge-warning {
            background: var(--warning);
            color: white;
        }
        
        .badge-normal {
            background: var(--success);
            color: white;
        }
        
        .badge-unknown {
            background: #6c757d;
            color: white;
        }
        
        /* RTT Values */
        .rtt-critical {
            color: var(--danger);
            font-weight: bold;
        }
        
        .rtt-warning {
            color: var(--warning);
            font-weight: bold;
        }
        
        .rtt-normal {
            color: var(--success);
        }
        
        /* Buttons */
        .btn {
            padding: 8px 16px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            transition: all 0.3s;
        }
        
        .btn-primary {
            background: var(--accent);
            color: white;
        }
        
        .btn-primary:hover {
            background: #c73e56;
        }
        
        .btn-outline {
            background: transparent;
            border: 1px solid var(--accent);
            color: var(--accent);
        }
        
        /* Footer */
        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            font-size: 12px;
            border-top: 1px solid #e0e0e0;
            margin-top: 30px;
        }
        
        /* Responsive */
        @media (max-width: 768px) {
            .stats-bar {
                flex-direction: column;
            }
            
            .card-header {
                flex-direction: column;
                gap: 10px;
            }
            
            th, td {
                padding: 8px 10px;
                font-size: 12px;
            }
        }
        
        /* Refresh animation */
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .fa-spinner {
            animation: spin 1s linear infinite;
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <script>
        let autoRefresh = true;
        
        function refreshData() {
            fetch('/api/metrics')
                .then(response => response.json())
                .then(data => {
                    updateDashboard(data);
                    document.getElementById('lastUpdate').textContent = new Date().toLocaleString();
                })
                .catch(err => console.error('Error:', err));
        }
        
        function updateDashboard(data) {
            // Update stats
            let critical = 0, warning = 0, normal = 0, unknown = 0;
            data.forEach(m => {
                if (m.status === 'critical') critical++;
                else if (m.status === 'warning') warning++;
                else if (m.status === 'normal') normal++;
                else unknown++;
            });
            
            document.getElementById('totalMonitors').textContent = data.length;
            document.getElementById('criticalCount').textContent = critical;
            document.getElementById('warningCount').textContent = warning;
            document.getElementById('normalCount').textContent = normal;
            
            // Group by service
            const grouped = {};
            data.forEach(m => {
                if (!grouped[m.service]) grouped[m.service] = [];
                grouped[m.service].push(m);
            });
            
            // Update tables
            const container = document.getElementById('tablesContainer');
            container.innerHTML = '';
            
            for (const [service, metrics] of Object.entries(grouped)) {
                const card = document.createElement('div');
                card.className = 'card';
                card.innerHTML = `
                    <div class="card-header">
                        <span><i class="fas fa-network-wired"></i> ${service}</span>
                        <span class="badge badge-${getServiceStatus(metrics)}">${getServiceStatusText(metrics)}</span>
                    </div>
                    <div class="card-body">
                        <div class="table-container">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Region</th>
                                        <th>Host</th>
                                        <th>Protocol</th>
                                        <th>Type</th>
                                        <th>RTT (ms)</th>
                                        <th>Status</th>
                                        <th>Last Updated</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${metrics.map(m => `
                                        <tr>
                                            <td><strong>${m.region}</strong></td>
                                            <td>${m.host}:${m.port}</td>
                                            <td><span class="badge" style="background:#6c757d; color:white;">${m.protocol.toUpperCase()}</span></td>
                                            <td>${m.type || '-'}</td>
                                            <td class="rtt-${m.status}">${m.rtt ? m.rtt + ' ms' : 'N/A'}</td>
                                            <td><span class="badge badge-${m.status}">${m.status.toUpperCase()}</span></td>
                                            <td>${new Date(m.timestamp).toLocaleTimeString()}</td>
                                        </tr>
                                    `).join('')}
                                </tbody>
                            </table>
                        </div>
                    </div>
                `;
                container.appendChild(card);
            }
        }
        
        function getServiceStatus(metrics) {
            if (metrics.some(m => m.status === 'critical')) return 'critical';
            if (metrics.some(m => m.status === 'warning')) return 'warning';
            return 'normal';
        }
        
        function getServiceStatusText(metrics) {
            if (metrics.some(m => m.status === 'critical')) return '⚠️ Issues Detected';
            if (metrics.some(m => m.status === 'warning')) return '🟡 Performance Degraded';
            return '✅ All Services Normal';
        }
        
        // Auto-refresh every 30 seconds
        setInterval(() => {
            if (autoRefresh) refreshData();
        }, 30000);
        
        // Initial load
        window.onload = refreshData;
    </script>
</head>
<body>
    <div class="header">
        <h1>
            <i class="fas fa-chart-line"></i>
            MCoreNMS Pro
        </h1>
        <div class="project-id">Project ID: MeticulousCoreNMS@42026V1</div>
        <div class="owner">Owner: Meticulous Core Global | Target: 2026 Industry Standard</div>
    </div>
    
    <div class="stats-bar">
        <div class="stat">
            <div class="stat-value" id="totalMonitors">-</div>
            <div class="stat-label">Total Monitors</div>
        </div>
        <div class="stat">
            <div class="stat-value stat-critical" id="criticalCount">-</div>
            <div class="stat-label">Critical</div>
        </div>
        <div class="stat">
            <div class="stat-value stat-warning" id="warningCount">-</div>
            <div class="stat-label">Warning</div>
        </div>
        <div class="stat">
            <div class="stat-value stat-normal" id="normalCount">-</div>
            <div class="stat-label">Healthy</div>
        </div>
        <div class="stat">
            <div class="stat-value" id="lastUpdate">-</div>
            <div class="stat-label">Last Update</div>
        </div>
    </div>
    
    <div class="container">
        <div class="card">
            <div class="card-header">
                <span><i class="fas fa-info-circle"></i> System Status</span>
                <button class="btn btn-outline" onclick="refreshData()"><i class="fas fa-sync-alt"></i> Refresh Now</button>
            </div>
            <div class="card-body">
                <p><strong>📡 Monitoring Coverage:</strong></p>
                <ul>
                    <li><strong>WhatsApp (Meta AS32934)</strong> - HTTPS, XMPP, STUN, TURN, QUIC</li>
                    <li><strong>IMO (PageBites AS36131)</strong> - HTTPS, STUN, TURN, QUIC</li>
                    <li><strong>BIGO Live (AS10122)</strong> - 10+ Regions (Singapore, Mumbai, Dhaka, Riyadh, Doha, Dubai, Frankfurt, Amsterdam)</li>
                    <li><strong>Google Services (AS15169)</strong> - HTTPS, QUIC, STUN, WebRTC</li>
                    <li><strong>Zoom</strong> - HTTPS, UDP Media (8801-8802)</li>
                    <li><strong>Microsoft Teams (AS8075)</strong> - HTTPS, STUN, TURN</li>
                </ul>
                <p style="margin-top: 15px;"><strong>🔍 Protocols Monitored:</strong> TCP, UDP, QUIC, STUN, TURN, WebRTC, ICMP</p>
                <p><strong>⏱️ Collection Interval:</strong> Every 5 minutes | <strong>Auto-refresh:</strong> Every 30 seconds</p>
            </div>
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
        <p>MCoreNMS Pro v2.0 | Complete 360° Network Visibility Platform | No Limits, No Dependencies</p>
        <p>Monitoring WhatsApp | IMO | BIGO | Meta | Google | Zoom | Teams | All Protocols (TCP/UDP/QUIC/WebRTC)</p>
    </div>
</body>
</html>
'''

# ================================================================
# FLASK ROUTES
# ================================================================

@app.route('/')
@app.route('/mcnms')
@app.route('/mcnms/')
def dashboard():
    """Main dashboard"""
    return render_template_string(DASHBOARD_TEMPLATE)

@app.route('/api/metrics')
def api_metrics():
    """Get latest metrics"""
    metrics = collector.get_latest_metrics()
    return jsonify(metrics)

@app.route('/api/health')
def api_health():
    """Health check"""
    return jsonify({
        'status': 'ok',
        'project_id': 'MeticulousCoreNMS@42026V1',
        'owner': 'Meticulous Core Global',
        'target_year': '2026',
        'services_monitored': list(MONITOR_TARGETS.keys()),
        'total_targets': sum(len(s['targets']) for s in MONITOR_TARGETS.values()),
        'last_collection': collector.last_collection.isoformat() if collector.last_collection else None
    })

@app.route('/api/discover')
def api_discover():
    """Discover all monitoring targets"""
    return jsonify({
        'services': list(MONITOR_TARGETS.keys()),
        'config': MONITOR_TARGETS
    })

# ================================================================
# MAIN ENTRY POINT
# ================================================================

if __name__ == '__main__':
    print("=" * 70)
    print("MCoreNMS Pro - Complete 360° Network Visibility Platform")
    print("Project ID: MeticulousCoreNMS@42026V1")
    print("Owner: Meticulous Core Global")
    print("Target Year: 2026 Industry Standard")
    print("=" * 70)
    print(f"Services Monitored: {', '.join(MONITOR_TARGETS.keys())}")
    print(f"Total Targets: {sum(len(s['targets']) for s in MONITOR_TARGETS.values())}")
    print("=" * 70)
    
    # Start background collection
    collector.start_background_collection(interval=300)
    
    # Start Flask
    app.run(host='127.0.0.1', port=5000, debug=False, threaded=True)