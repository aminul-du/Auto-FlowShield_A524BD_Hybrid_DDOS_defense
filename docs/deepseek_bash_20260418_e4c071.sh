cat > /tmp/mcnms-final-complete.sh << 'EOF'
#!/bin/bash
echo "========================================="
echo "MCoreNMS Pro - FINAL COMPLETE DEPLOYMENT"
echo "38 Existing Services + Global Gov/Edu Sites"
echo "Project ID: MeticulousCoreNMS@42026V1"
echo "========================================="

# Create directories
sudo mkdir -p /opt/mcore-nms
sudo mkdir -p /var/www/html/mcnms
sudo mkdir -p /var/lib/mcnms/data
sudo mkdir -p /var/log/mcnms

# Detect domain
DETECTED_DOMAIN=$(hostname -f 2>/dev/null || echo "157.119.185.254")

# ================================================================
# COMPLETE COLLECTOR - ALL SERVICES (Existing + New Global)
# ================================================================
sudo tee /opt/mcore-nms/collector.py << 'PYEOF'
#!/usr/bin/env python3
"""
MCoreNMS Pro v6.0 - Complete Global Monitor
Includes: 38 original services + 60+ global government/education sites
"""

import socket
import time
import json
import os
import subprocess
import re
from datetime import datetime

DATA_FILE = '/var/www/html/mcnms/data.json'
HISTORY_FILE = '/var/www/html/mcnms/history.json'
ALERTS_FILE = '/var/lib/mcnms/data/alerts.json'

# ================================================================
# SECTION 1: EXISTING 38 SERVICES (KEPT AS-IS)
# ================================================================
EXISTING_SERVICES = [
    # Meta / Facebook Family
    {'service': 'Meta/Facebook', 'category': 'Social', 'region': 'Global', 'host': 'facebook.com', 'port': 443, 'protocol': 'tcp', 'icon': '📘', 'priority': 'High'},
    {'service': 'WhatsApp', 'category': 'Messaging', 'region': 'Global', 'host': 'whatsapp.com', 'port': 443, 'protocol': 'tcp', 'icon': '💬', 'priority': 'Critical'},
    {'service': 'WhatsApp', 'category': 'Messaging', 'region': 'XMPP', 'host': 'whatsapp.com', 'port': 5222, 'protocol': 'tcp', 'icon': '💬', 'priority': 'Critical'},
    {'service': 'Instagram', 'category': 'Social', 'region': 'Global', 'host': 'instagram.com', 'port': 443, 'protocol': 'tcp', 'icon': '📸', 'priority': 'Medium'},
    
    # Google Services
    {'service': 'Google', 'category': 'Search', 'region': 'Global', 'host': 'google.com', 'port': 443, 'protocol': 'tcp', 'icon': '🔍', 'priority': 'High'},
    {'service': 'YouTube', 'category': 'Video', 'region': 'Global', 'host': 'youtube.com', 'port': 443, 'protocol': 'tcp', 'icon': '📺', 'priority': 'High'},
    {'service': 'Gmail', 'category': 'Email', 'region': 'Global', 'host': 'gmail.com', 'port': 443, 'protocol': 'tcp', 'icon': '📧', 'priority': 'High'},
    {'service': 'Google Drive', 'category': 'Cloud', 'region': 'Global', 'host': 'drive.google.com', 'port': 443, 'protocol': 'tcp', 'icon': '☁️', 'priority': 'Medium'},
    {'service': 'Google Meet', 'category': 'Video', 'region': 'Global', 'host': 'meet.google.com', 'port': 443, 'protocol': 'tcp', 'icon': '🎥', 'priority': 'High'},
    
    # IMO
    {'service': 'IMO', 'category': 'Messaging', 'region': 'Global', 'host': 'imo.im', 'port': 443, 'protocol': 'tcp', 'icon': '📱', 'priority': 'High'},
    
    # BIGO Live - US/EU only (as requested)
    {'service': 'BIGO Live', 'category': 'Streaming', 'region': 'USA (Virginia)', 'host': '169.136.136.113', 'port': 443, 'protocol': 'tcp', 'icon': '🎥', 'priority': 'Medium'},
    {'service': 'BIGO Live', 'category': 'Streaming', 'region': 'USA (California)', 'host': '169.136.136.120', 'port': 443, 'protocol': 'tcp', 'icon': '🎥', 'priority': 'Medium'},
    {'service': 'BIGO Live', 'category': 'Streaming', 'region': 'Germany (Frankfurt)', 'host': '164.90.72.177', 'port': 443, 'protocol': 'tcp', 'icon': '🎥', 'priority': 'Medium'},
    {'service': 'BIGO Live', 'category': 'Streaming', 'region': 'Netherlands (Amsterdam)', 'host': '202.168.102.29', 'port': 443, 'protocol': 'tcp', 'icon': '🎥', 'priority': 'Medium'},
    
    # Video Conferencing
    {'service': 'Zoom', 'category': 'Video', 'region': 'Global', 'host': 'zoom.us', 'port': 443, 'protocol': 'tcp', 'icon': '🎬', 'priority': 'High'},
    {'service': 'Microsoft Teams', 'category': 'Video', 'region': 'Global', 'host': 'teams.microsoft.com', 'port': 443, 'protocol': 'tcp', 'icon': '👥', 'priority': 'High'},
    
    # Freelance Platforms
    {'service': 'Upwork', 'category': 'Freelance', 'region': 'USA', 'host': 'upwork.com', 'port': 443, 'protocol': 'tcp', 'icon': '💼', 'priority': 'Medium'},
    {'service': 'Fiverr', 'category': 'Freelance', 'region': 'Israel', 'host': 'fiverr.com', 'port': 443, 'protocol': 'tcp', 'icon': '💼', 'priority': 'Medium'},
    {'service': 'Freelancer', 'category': 'Freelance', 'region': 'Australia', 'host': 'freelancer.com', 'port': 443, 'protocol': 'tcp', 'icon': '💼', 'priority': 'Medium'},
    {'service': 'Toptal', 'category': 'Freelance', 'region': 'USA', 'host': 'toptal.com', 'port': 443, 'protocol': 'tcp', 'icon': '💼', 'priority': 'Low'},
    {'service': 'Guru', 'category': 'Freelance', 'region': 'USA', 'host': 'guru.com', 'port': 443, 'protocol': 'tcp', 'icon': '💼', 'priority': 'Low'},
    
    # Bangladesh Government Sites
    {'service': 'Bangladesh Govt', 'category': 'Government', 'region': 'Dhaka', 'host': 'gov.bd', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'High'},
    {'service': 'Bangladesh Police', 'category': 'Government', 'region': 'Dhaka', 'host': 'police.gov.bd', 'port': 443, 'protocol': 'tcp', 'icon': '👮', 'priority': 'High'},
    {'service': 'Bangladesh Bank', 'category': 'Government', 'region': 'Dhaka', 'host': 'bb.org.bd', 'port': 443, 'protocol': 'tcp', 'icon': '🏦', 'priority': 'High'},
    {'service': 'BTRC', 'category': 'Government', 'region': 'Dhaka', 'host': 'btrc.gov.bd', 'port': 443, 'protocol': 'tcp', 'icon': '📡', 'priority': 'High'},
    {'service': 'National Web Portal', 'category': 'Government', 'region': 'Dhaka', 'host': 'bangladesh.gov.bd', 'port': 443, 'protocol': 'tcp', 'icon': '🌐', 'priority': 'High'},
    {'service': 'Prime Minister Office', 'category': 'Government', 'region': 'Dhaka', 'host': 'pmo.gov.bd', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'High'},
    
    # Top 3 News Sites
    {'service': 'Prothom Alo', 'category': 'News', 'region': 'Dhaka', 'host': 'prothomalo.com', 'port': 443, 'protocol': 'tcp', 'icon': '📰', 'priority': 'Medium'},
    {'service': 'The Daily Star', 'category': 'News', 'region': 'Dhaka', 'host': 'thedailystar.net', 'port': 443, 'protocol': 'tcp', 'icon': '📰', 'priority': 'Medium'},
    {'service': 'Dhaka Tribune', 'category': 'News', 'region': 'Dhaka', 'host': 'dhakatribune.com', 'port': 443, 'protocol': 'tcp', 'icon': '📰', 'priority': 'Medium'},
    
    # Gaming & CDN
    {'service': 'Steam', 'category': 'Gaming', 'region': 'Global', 'host': 'steamcommunity.com', 'port': 443, 'protocol': 'tcp', 'icon': '🎮', 'priority': 'Low'},
    {'service': 'Epic Games', 'category': 'Gaming', 'region': 'Global', 'host': 'epicgames.com', 'port': 443, 'protocol': 'tcp', 'icon': '🎮', 'priority': 'Low'},
    {'service': 'Netflix', 'category': 'Streaming', 'region': 'Global', 'host': 'netflix.com', 'port': 443, 'protocol': 'tcp', 'icon': '📺', 'priority': 'Medium'},
    {'service': 'Twitch', 'category': 'Streaming', 'region': 'Global', 'host': 'twitch.tv', 'port': 443, 'protocol': 'tcp', 'icon': '📺', 'priority': 'Low'},
    {'service': 'Discord', 'category': 'Voice', 'region': 'Global', 'host': 'discord.com', 'port': 443, 'protocol': 'tcp', 'icon': '🎙️', 'priority': 'Low'},
    {'service': 'Cloudflare', 'category': 'CDN', 'region': 'Global', 'host': 'cloudflare.com', 'port': 443, 'protocol': 'tcp', 'icon': '🌐', 'priority': 'Medium'},
    {'service': 'Akamai', 'category': 'CDN', 'region': 'Global', 'host': 'akamai.com', 'port': 443, 'protocol': 'tcp', 'icon': '🌐', 'priority': 'Medium'},
]

# ================================================================
# SECTION 2: NEW GLOBAL GOVERNMENT & EDUCATION SITES
# ================================================================
GLOBAL_SITES = [
    # USA (Top)
    {'service': 'NASA', 'category': 'Government', 'region': 'USA', 'host': 'nasa.gov', 'port': 443, 'protocol': 'tcp', 'icon': '🚀', 'priority': 'Top'},
    {'service': 'MIT', 'category': 'Education', 'region': 'USA', 'host': 'mit.edu', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Top'},
    {'service': 'USA.gov', 'category': 'Government', 'region': 'USA', 'host': 'usa.gov', 'port': 443, 'protocol': 'tcp', 'icon': '🇺🇸', 'priority': 'Top'},
    
    # Singapore (Top)
    {'service': 'Singapore Govt', 'category': 'Government', 'region': 'Singapore', 'host': 'gov.sg', 'port': 443, 'protocol': 'tcp', 'icon': '🇸🇬', 'priority': 'Top'},
    {'service': 'NUS', 'category': 'Education', 'region': 'Singapore', 'host': 'nus.edu.sg', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Top'},
    {'service': 'Singpass', 'category': 'Government', 'region': 'Singapore', 'host': 'singpass.gov.sg', 'port': 443, 'protocol': 'tcp', 'icon': '🔐', 'priority': 'Top'},
    
    # India (Top)
    {'service': 'NIC India', 'category': 'Government', 'region': 'India', 'host': 'nic.in', 'port': 443, 'protocol': 'tcp', 'icon': '🇮🇳', 'priority': 'Top'},
    {'service': 'India Govt', 'category': 'Government', 'region': 'India', 'host': 'india.gov.in', 'port': 443, 'protocol': 'tcp', 'icon': '🇮🇳', 'priority': 'Top'},
    {'service': 'IIT Bombay', 'category': 'Education', 'region': 'India', 'host': 'iitb.ac.in', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Top'},
    
    # Hong Kong (Top)
    {'service': 'Hong Kong Govt', 'category': 'Government', 'region': 'Hong Kong', 'host': 'gov.hk', 'port': 443, 'protocol': 'tcp', 'icon': '🇭🇰', 'priority': 'Top'},
    {'service': 'HKU', 'category': 'Education', 'region': 'Hong Kong', 'host': 'hku.hk', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Top'},
    {'service': 'CSD Hong Kong', 'category': 'Government', 'region': 'Hong Kong', 'host': 'csd.gov.hk', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Top'},
    
    # Netherlands (Top)
    {'service': 'Netherlands Govt', 'category': 'Government', 'region': 'Netherlands', 'host': 'overheid.nl', 'port': 443, 'protocol': 'tcp', 'icon': '🇳🇱', 'priority': 'Top'},
    {'service': 'TU Delft', 'category': 'Education', 'region': 'Netherlands', 'host': 'tudelft.nl', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Top'},
    {'service': 'Dutch Govt', 'category': 'Government', 'region': 'Netherlands', 'host': 'government.nl', 'port': 443, 'protocol': 'tcp', 'icon': '🇳🇱', 'priority': 'Top'},
    
    # United Kingdom (Top)
    {'service': 'UK Govt', 'category': 'Government', 'region': 'UK', 'host': 'gov.uk', 'port': 443, 'protocol': 'tcp', 'icon': '🇬🇧', 'priority': 'Top'},
    {'service': 'Cambridge', 'category': 'Education', 'region': 'UK', 'host': 'cam.ac.uk', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Top'},
    {'service': 'NHS', 'category': 'Health', 'region': 'UK', 'host': 'nhs.uk', 'port': 443, 'protocol': 'tcp', 'icon': '🏥', 'priority': 'Top'},
    
    # Germany (Top)
    {'service': 'Bund', 'category': 'Government', 'region': 'Germany', 'host': 'bund.de', 'port': 443, 'protocol': 'tcp', 'icon': '🇩🇪', 'priority': 'Top'},
    {'service': 'TUM', 'category': 'Education', 'region': 'Germany', 'host': 'tum.de', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Top'},
    {'service': 'Bavaria', 'category': 'Government', 'region': 'Germany', 'host': 'bayern.de', 'port': 443, 'protocol': 'tcp', 'icon': '🇩🇪', 'priority': 'Top'},
    
    # Malaysia (Medium)
    {'service': 'Malaysia Govt', 'category': 'Government', 'region': 'Malaysia', 'host': 'malaysia.gov.my', 'port': 443, 'protocol': 'tcp', 'icon': '🇲🇾', 'priority': 'Medium'},
    {'service': 'UM', 'category': 'Education', 'region': 'Malaysia', 'host': 'um.edu.my', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Medium'},
    {'service': 'JPN', 'category': 'Government', 'region': 'Malaysia', 'host': 'jpn.gov.my', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Medium'},
    
    # Thailand (Medium)
    {'service': 'Thailand Govt', 'category': 'Government', 'region': 'Thailand', 'host': 'thailand.go.th', 'port': 443, 'protocol': 'tcp', 'icon': '🇹🇭', 'priority': 'Medium'},
    {'service': 'Chulalongkorn', 'category': 'Education', 'region': 'Thailand', 'host': 'chula.ac.th', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Medium'},
    {'service': 'MOPH Thailand', 'category': 'Health', 'region': 'Thailand', 'host': 'moph.go.th', 'port': 443, 'protocol': 'tcp', 'icon': '🏥', 'priority': 'Medium'},
    
    # UAE (Medium)
    {'service': 'UAE Portal', 'category': 'Government', 'region': 'UAE', 'host': 'u.ae', 'port': 443, 'protocol': 'tcp', 'icon': '🇦🇪', 'priority': 'Medium'},
    {'service': 'MOHRE', 'category': 'Government', 'region': 'UAE', 'host': 'mohre.gov.ae', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Medium'},
    {'service': 'UAEU', 'category': 'Education', 'region': 'UAE', 'host': 'uaeu.ac.ae', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Medium'},
    
    # Japan (Medium)
    {'service': 'Japan Govt', 'category': 'Government', 'region': 'Japan', 'host': 'go.jp', 'port': 443, 'protocol': 'tcp', 'icon': '🇯🇵', 'priority': 'Medium'},
    {'service': 'UTokyo', 'category': 'Education', 'region': 'Japan', 'host': 'u-tokyo.ac.jp', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Medium'},
    {'service': 'JAXA', 'category': 'Space', 'region': 'Japan', 'host': 'jaxa.jp', 'port': 443, 'protocol': 'tcp', 'icon': '🛰️', 'priority': 'Medium'},
    
    # South Korea (Medium)
    {'service': 'Korea Portal', 'category': 'Government', 'region': 'South Korea', 'host': 'korea.kr', 'port': 443, 'protocol': 'tcp', 'icon': '🇰🇷', 'priority': 'Medium'},
    {'service': 'SNU', 'category': 'Education', 'region': 'South Korea', 'host': 'snu.ac.kr', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Medium'},
    {'service': 'MOEL', 'category': 'Government', 'region': 'South Korea', 'host': 'moel.go.kr', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Medium'},
    
    # France (Medium)
    {'service': 'French Govt', 'category': 'Government', 'region': 'France', 'host': 'gouvernement.fr', 'port': 443, 'protocol': 'tcp', 'icon': '🇫🇷', 'priority': 'Medium'},
    {'service': 'Sorbonne', 'category': 'Education', 'region': 'France', 'host': 'sorbonne-universite.fr', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Medium'},
    {'service': 'Education France', 'category': 'Government', 'region': 'France', 'host': 'education.gouv.fr', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Medium'},
    
    # Canada (Medium)
    {'service': 'Canada.ca', 'category': 'Government', 'region': 'Canada', 'host': 'canada.ca', 'port': 443, 'protocol': 'tcp', 'icon': '🇨🇦', 'priority': 'Medium'},
    {'service': 'U Toronto', 'category': 'Education', 'region': 'Canada', 'host': 'utoronto.ca', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Medium'},
    {'service': 'GC.ca', 'category': 'Government', 'region': 'Canada', 'host': 'gc.ca', 'port': 443, 'protocol': 'tcp', 'icon': '🇨🇦', 'priority': 'Medium'},
    
    # Qatar (Low)
    {'service': 'Qatar Govt', 'category': 'Government', 'region': 'Qatar', 'host': 'gov.qa', 'port': 443, 'protocol': 'tcp', 'icon': '🇶🇦', 'priority': 'Low'},
    {'service': 'QU', 'category': 'Education', 'region': 'Qatar', 'host': 'qu.edu.qa', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Low'},
    {'service': 'Hukoomi', 'category': 'Government', 'region': 'Qatar', 'host': 'hukoomi.gov.qa', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Low'},
    
    # Oman (Low)
    {'service': 'Oman.om', 'category': 'Government', 'region': 'Oman', 'host': 'oman.om', 'port': 443, 'protocol': 'tcp', 'icon': '🇴🇲', 'priority': 'Low'},
    {'service': 'SQU', 'category': 'Education', 'region': 'Oman', 'host': 'squ.edu.om', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Low'},
    {'service': 'eOman', 'category': 'Government', 'region': 'Oman', 'host': 'eoman.om', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Low'},
    
    # Saudi Arabia (Low)
    {'service': 'Saudi Govt', 'category': 'Government', 'region': 'Saudi Arabia', 'host': 'my.gov.sa', 'port': 443, 'protocol': 'tcp', 'icon': '🇸🇦', 'priority': 'Low'},
    {'service': 'KAU', 'category': 'Education', 'region': 'Saudi Arabia', 'host': 'kau.edu.sa', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Low'},
    {'service': 'Saudi MOE', 'category': 'Government', 'region': 'Saudi Arabia', 'host': 'moe.gov.sa', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Low'},
    
    # South Africa (Low)
    {'service': 'SA Govt', 'category': 'Government', 'region': 'South Africa', 'host': 'gov.za', 'port': 443, 'protocol': 'tcp', 'icon': '🇿🇦', 'priority': 'Low'},
    {'service': 'UCT', 'category': 'Education', 'region': 'South Africa', 'host': 'uct.ac.za', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Low'},
    {'service': 'DBE', 'category': 'Government', 'region': 'South Africa', 'host': 'dbe.gov.za', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Low'},
    
    # Brazil (Low)
    {'service': 'Brazil Govt', 'category': 'Government', 'region': 'Brazil', 'host': 'gov.br', 'port': 443, 'protocol': 'tcp', 'icon': '🇧🇷', 'priority': 'Low'},
    {'service': 'USP', 'category': 'Education', 'region': 'Brazil', 'host': 'usp.br', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Low'},
    {'service': 'MEC Brazil', 'category': 'Government', 'region': 'Brazil', 'host': 'mec.gov.br', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Low'},
    
    # Turkey (Low)
    {'service': 'Turkiye', 'category': 'Government', 'region': 'Turkey', 'host': 'turkiye.gov.tr', 'port': 443, 'protocol': 'tcp', 'icon': '🇹🇷', 'priority': 'Low'},
    {'service': 'METU', 'category': 'Education', 'region': 'Turkey', 'host': 'metu.edu.tr', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Low'},
    {'service': 'MEB', 'category': 'Government', 'region': 'Turkey', 'host': 'meb.gov.tr', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Low'},
    
    # Poland (Low)
    {'service': 'Poland Govt', 'category': 'Government', 'region': 'Poland', 'host': 'gov.pl', 'port': 443, 'protocol': 'tcp', 'icon': '🇵🇱', 'priority': 'Low'},
    {'service': 'UW', 'category': 'Education', 'region': 'Poland', 'host': 'uw.edu.pl', 'port': 443, 'protocol': 'tcp', 'icon': '🎓', 'priority': 'Low'},
    {'service': 'Nauka', 'category': 'Government', 'region': 'Poland', 'host': 'nauka.gov.pl', 'port': 443, 'protocol': 'tcp', 'icon': '🏛️', 'priority': 'Low'},
]

# Combine all services
ALL_SERVICES = EXISTING_SERVICES + GLOBAL_SITES

# ================================================================
# PROBE FUNCTIONS (Same as before)
# ================================================================
def tcp_ping(host, port, timeout=5):
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

def packet_loss_test(host, count=3):
    try:
        cmd = ['ping', '-c', str(count), '-W', '2', host]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        loss_match = re.search(r'(\d+)% packet loss', result.stdout)
        packet_loss = int(loss_match.group(1)) if loss_match else 100
        rtt_matches = re.findall(r'time=([\d.]+) ms', result.stdout)
        rtt_values = [float(x) for x in rtt_matches]
        avg_rtt = sum(rtt_values) / len(rtt_values) if rtt_values else None
        jitter = 0
        if len(rtt_values) > 1:
            differences = [abs(rtt_values[i] - rtt_values[i-1]) for i in range(1, len(rtt_values))]
            jitter = sum(differences) / len(differences)
        return {'loss': packet_loss, 'avg_rtt': avg_rtt, 'jitter': round(jitter, 2)}
    except:
        return {'loss': 100, 'avg_rtt': None, 'jitter': 0}

def get_asn_info(host):
    asn_map = {
        'nasa.gov': 'AS1239 (NASA)', 'mit.edu': 'AS3 (MIT)', 'usa.gov': 'AS1239 (US Govt)',
        'gov.sg': 'AS3491 (Singapore)', 'nus.edu.sg': 'AS3491 (NUS)', 'singpass.gov.sg': 'AS3491 (Singapore)',
        'nic.in': 'AS4758 (NIC)', 'india.gov.in': 'AS4758 (India)', 'iitb.ac.in': 'AS4758 (IIT)',
        'gov.hk': 'AS4515 (HK)', 'hku.hk': 'AS4515 (HKU)', 'csd.gov.hk': 'AS4515 (HK)',
        'overheid.nl': 'AS1103 (NL)', 'tudelft.nl': 'AS1103 (TU Delft)', 'government.nl': 'AS1103 (NL)',
        'gov.uk': 'AS5430 (UK)', 'cam.ac.uk': 'AS5430 (Cambridge)', 'nhs.uk': 'AS5430 (NHS)',
        'bund.de': 'AS680 (DE)', 'tum.de': 'AS680 (TUM)', 'bayern.de': 'AS680 (Bavaria)',
        'facebook.com': 'AS32934 (Meta)', 'whatsapp.com': 'AS32934 (Meta)', 'google.com': 'AS15169 (Google)',
        'zoom.us': 'AS27647 (Zoom)', 'teams.microsoft.com': 'AS8075 (Microsoft)',
    }
    for key, value in asn_map.items():
        if key in host:
            return value
    return 'Global CDN'

def get_quality_score(rtt, loss, jitter):
    score = 100
    if rtt and rtt > 100:
        score -= min(40, (rtt - 100) / 2.5)
    if loss > 0:
        score -= min(40, loss * 4)
    if jitter > 30:
        score -= min(20, (jitter - 30) / 1.5)
    return max(0, min(100, round(score)))

def get_status(rtt, loss):
    if rtt is None:
        return 'unknown'
    if loss > 10 or rtt > 300:
        return 'critical'
    if loss > 3 or rtt > 150:
        return 'warning'
    return 'normal'

def collect_all():
    all_metrics = []
    timestamp = datetime.now().strftime('%H:%M:%S')
    date_str = datetime.now().strftime('%Y-%m-%d')
    
    print(f"[{datetime.now()}] Starting collection for {len(ALL_SERVICES)} services...")
    
    for svc in ALL_SERVICES:
        loss_result = packet_loss_test(svc['host'])
        rtt = loss_result['avg_rtt'] if loss_result['avg_rtt'] else tcp_ping(svc['host'], svc['port'])
        
        quality = get_quality_score(rtt, loss_result['loss'], loss_result['jitter'])
        status = get_status(rtt, loss_result['loss'])
        
        metric = {
            'service': svc['service'],
            'category': svc['category'],
            'region': svc['region'],
            'host': svc['host'],
            'port': svc['port'],
            'protocol': svc['protocol'].upper(),
            'icon': svc['icon'],
            'priority': svc.get('priority', 'Medium'),
            'rtt': rtt,
            'packet_loss': loss_result['loss'],
            'jitter': loss_result['jitter'],
            'quality': quality,
            'status': status,
            'asn': get_asn_info(svc['host']),
            'time': timestamp,
            'date': date_str
        }
        all_metrics.append(metric)
        
        if rtt:
            print(f"  ✅ {svc['icon']} {svc['service']} - {svc['region']}: {rtt}ms")
        else:
            print(f"  ❌ {svc['icon']} {svc['service']} - {svc['region']}: FAILED")
    
    summary = {
        'total': len(all_metrics),
        'critical': sum(1 for m in all_metrics if m['status'] == 'critical'),
        'warning': sum(1 for m in all_metrics if m['status'] == 'warning'),
        'normal': sum(1 for m in all_metrics if m['status'] == 'normal'),
        'avg_quality': round(sum(m['quality'] for m in all_metrics) / len(all_metrics), 1),
        'last_update': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'categories': list(set(m['category'] for m in all_metrics))
    }
    
    with open(DATA_FILE, 'w') as f:
        json.dump({'metrics': all_metrics, 'summary': summary}, f, indent=2)
    
    # Save history
    history = []
    if os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, 'r') as f:
            history = json.load(f)
    history.append({
        'timestamp': datetime.now().isoformat(),
        'critical': summary['critical'],
        'warning': summary['warning'],
        'normal': summary['normal'],
        'avg_quality': summary['avg_quality']
    })
    if len(history) > 288:
        history = history[-288:]
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f, indent=2)
    
    print(f"\n✅ Collection complete: {summary['total']} metrics | Critical: {summary['critical']} | Avg Quality: {summary['avg_quality']}%")
    return all_metrics

if __name__ == '__main__':
    collect_all()
PYEOF

# ================================================================
# DEPLOY DASHBOARD (Same as before, no changes needed)
# ================================================================
sudo tee /var/www/html/mcnms/index.html << 'HTEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>MCoreNMS Pro - Global Network Monitor</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        :root {
            --primary: #1a1a2e;
            --secondary: #16213e;
            --accent: #e94560;
            --success: #28a745;
            --warning: #ffc107;
            --danger: #dc3545;
        }
        body { font-family: 'Inter', sans-serif; background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); min-height: 100vh; }
        .header { background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%); color: white; padding: 20px 30px; }
        .header-content { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 20px; }
        .logo-area { display: flex; align-items: center; gap: 15px; }
        .logo { width: 50px; height: 50px; background: var(--accent); border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 28px; }
        .title h1 { font-size: 24px; margin: 0; }
        .title p { font-size: 11px; opacity: 0.7; margin-top: 5px; }
        .domain-badge { background: rgba(255,255,255,0.1); padding: 8px 15px; border-radius: 20px; font-size: 12px; font-family: monospace; }
        .nav-links { background: white; padding: 12px 30px; display: flex; gap: 15px; flex-wrap: wrap; border-bottom: 1px solid #e0e0e0; }
        .nav-link { text-decoration: none; color: var(--primary); font-weight: 500; padding: 8px 16px; border-radius: 8px; transition: all 0.3s; }
        .nav-link:hover { background: var(--accent); color: white; }
        .search-container { background: white; padding: 15px 30px; border-bottom: 1px solid #e0e0e0; }
        .search-box { display: flex; gap: 10px; max-width: 500px; }
        .search-input { flex: 1; padding: 12px 20px; border: 2px solid #e0e0e0; border-radius: 30px; font-size: 14px; outline: none; }
        .search-input:focus { border-color: var(--accent); }
        .search-btn, .report-btn { padding: 12px 25px; background: var(--accent); color: white; border: none; border-radius: 30px; cursor: pointer; font-weight: 600; }
        .report-btn { background: var(--primary); }
        .stats-bar { display: flex; gap: 20px; padding: 20px 30px; background: white; flex-wrap: wrap; }
        .stat { flex: 1; min-width: 120px; text-align: center; padding: 15px; background: #f8f9fa; border-radius: 12px; cursor: pointer; transition: transform 0.3s; }
        .stat:hover { transform: translateY(-3px); }
        .stat-value { font-size: 28px; font-weight: bold; }
        .stat-label { font-size: 12px; color: #666; margin-top: 5px; }
        .container { max-width: 1600px; margin: 20px auto; padding: 0 20px; }
        .card { background: white; border-radius: 12px; margin-bottom: 20px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
        .card-header { background: var(--primary); color: white; padding: 15px 20px; font-weight: 600; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
        .card-body { padding: 20px; overflow-x: auto; max-height: 500px; overflow-y: auto; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #eee; font-size: 13px; }
        th { background: #f8f9fa; color: var(--primary); font-weight: 600; position: sticky; top: 0; }
        tr:hover { background: #f8f9fa; }
        .badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 600; color: white; }
        .badge-critical { background: var(--danger); }
        .badge-warning { background: var(--warning); color: #333; }
        .badge-normal { background: var(--success); }
        .quality-bar { width: 60px; height: 6px; background: #e0e0e0; border-radius: 3px; display: inline-block; margin-right: 5px; }
        .quality-fill { height: 100%; border-radius: 3px; }
        .quality-high { background: var(--success); }
        .quality-medium { background: var(--warning); }
        .quality-low { background: var(--danger); }
        .critical { color: var(--danger); font-weight: bold; }
        .warning { color: var(--warning); font-weight: bold; }
        .normal { color: var(--success); }
        .footer { text-align: center; padding: 20px; color: #666; font-size: 11px; border-top: 1px solid #e0e0e0; background: white; }
        .no-results { text-align: center; padding: 40px; color: #666; }
        @media (max-width: 768px) { th, td { font-size: 10px; padding: 8px; } }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-content">
            <div class="logo-area">
                <div class="logo">📡</div>
                <div class="title">
                    <h1>MCoreNMS Pro - Global Monitor</h1>
                    <p>Project ID: MeticulousCoreNMS@42026V1 | Owner: Meticulous Core Global</p>
                </div>
            </div>
            <div class="domain-badge"><i class="fas fa-globe"></i> <span id="domainName">Loading...</span></div>
        </div>
    </div>
    <div class="nav-links">
        <a href="/mcnms/" class="nav-link"><i class="fas fa-tachometer-alt"></i> Dashboard</a>
        <a href="/smokeping/smokeping.cgi" class="nav-link"><i class="fas fa-chart-line"></i> Smokeping</a>
        <a href="/mcnms/report.html" class="nav-link"><i class="fas fa-file-alt"></i> HOD Report</a>
    </div>
    <div class="search-container">
        <div class="search-box">
            <input type="text" id="searchInput" class="search-input" placeholder="🔍 Search by service, region, host, category...">
            <button class="search-btn" onclick="searchServices()"><i class="fas fa-search"></i> Search</button>
            <button class="report-btn" onclick="generateHODReport()"><i class="fas fa-download"></i> Generate HOD Report</button>
        </div>
    </div>
    <div class="stats-bar" id="statsBar"></div>
    <div class="container" id="tablesContainer"></div>
    <div class="footer"><span id="lastUpdate">Loading...</span></div>

    <script>
        let allMetrics = [];
        document.getElementById('domainName').textContent = window.location.hostname;
        
        function loadData() {
            fetch('/mcnms/data.json?' + new Date().getTime())
                .then(r => r.json())
                .then(data => {
                    allMetrics = data.metrics || [];
                    renderDashboard();
                    document.getElementById('lastUpdate').textContent = 'Last updated: ' + (data.summary?.last_update || new Date().toLocaleString());
                })
                .catch(err => console.error('Error:', err));
        }
        
        function renderDashboard() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            let filtered = allMetrics;
            if (searchTerm) {
                filtered = filtered.filter(m => 
                    m.service.toLowerCase().includes(searchTerm) ||
                    m.region.toLowerCase().includes(searchTerm) ||
                    m.host.toLowerCase().includes(searchTerm) ||
                    m.category.toLowerCase().includes(searchTerm)
                );
            }
            const critical = filtered.filter(m => m.status === 'critical').length;
            const warning = filtered.filter(m => m.status === 'warning').length;
            const normal = filtered.filter(m => m.status === 'normal').length;
            const avgQuality = Math.round(filtered.reduce((sum, m) => sum + (m.quality || 0), 0) / filtered.length);
            document.getElementById('statsBar').innerHTML = `
                <div class="stat"><div class="stat-value">${filtered.length}</div><div class="stat-label">Total</div></div>
                <div class="stat"><div class="stat-value" style="color:#dc3545">${critical}</div><div class="stat-label">Critical</div></div>
                <div class="stat"><div class="stat-value" style="color:#ffc107">${warning}</div><div class="stat-label">Warning</div></div>
                <div class="stat"><div class="stat-value" style="color:#28a745">${normal}</div><div class="stat-label">Healthy</div></div>
                <div class="stat"><div class="stat-value">${avgQuality}%</div><div class="stat-label">Quality</div></div>
            `;
            const grouped = {};
            filtered.forEach(m => { if (!grouped[m.service]) grouped[m.service] = []; grouped[m.service].push(m); });
            const container = document.getElementById('tablesContainer');
            container.innerHTML = '';
            if (Object.keys(grouped).length === 0) {
                container.innerHTML = '<div class="card"><div class="card-body"><div class="no-results"><i class="fas fa-search fa-3x"></i><p>No services found.</p></div></div></div>';
                return;
            }
            for (const [service, metrics] of Object.entries(grouped)) {
                const hasCritical = metrics.some(m => m.status === 'critical');
                const badgeClass = hasCritical ? 'critical' : (metrics.some(m => m.status === 'warning') ? 'warning' : 'normal');
                const badgeText = hasCritical ? '⚠️ Issues' : (metrics.some(m => m.status === 'warning') ? '🟡 Warning' : '✅ Healthy');
                const icon = metrics[0]?.icon || '🌐';
                let html = `<div class="card"><div class="card-header"><span>${icon} ${service}</span><span class="badge badge-${badgeClass}">${badgeText}</span></div><div class="card-body"><table><thead><tr>
                    <th>Region</th><th>Host</th><th>Protocol</th><th>RTT</th><th>Loss</th><th>Jitter</th><th>Quality</th><th>Status</th>
                </tr></thead><tbody>`;
                metrics.forEach(m => {
                    const qualityClass = (m.quality || 0) >= 80 ? 'quality-high' : ((m.quality || 0) >= 50 ? 'quality-medium' : 'quality-low');
                    html += `<tr>
                        <td><strong>${m.region}</strong></td>
                        <td><small>${m.host}:${m.port}</small></td>
                        <td><span class="badge" style="background:#6c757d">${m.protocol}</span></td>
                        <td class="${m.status}">${m.rtt ? m.rtt + 'ms' : 'N/A'}</td>
                        <td class="${m.packet_loss > 10 ? 'critical' : (m.packet_loss > 3 ? 'warning' : 'normal')}">${m.packet_loss}%</td>
                        <td class="${m.jitter > 50 ? 'critical' : (m.jitter > 30 ? 'warning' : 'normal')}">${m.jitter}ms</td>
                        <td><div class="quality-bar"><div class="quality-fill ${qualityClass}" style="width: ${m.quality || 0}%"></div></div>${m.quality || 0}%</td>
                        <td><span class="badge badge-${m.status}">${m.status}</span></td>
                    </tr>`;
                });
                html += `</tbody></table></div></div>`;
                container.innerHTML += html;
            }
        }
        
        function searchServices() { renderDashboard(); }
        
        function generateHODReport() {
            const critical = allMetrics.filter(m => m.status === 'critical');
            const warning = allMetrics.filter(m => m.status === 'warning');
            const date = new Date().toLocaleString();
            let report = `MCoreNMS Pro - HOD Network Performance Report\n`;
            report += `=${'='.repeat(50)}\n`;
            report += `Report Generated: ${date}\n`;
            report += `Project ID: MeticulousCoreNMS@42026V1\n`;
            report += `Owner: Meticulous Core Global\n`;
            report += `=${'='.repeat(50)}\n\n`;
            report += `📊 SUMMARY STATISTICS\n`;
            report += `- Total Monitors: ${allMetrics.length}\n`;
            report += `- Critical Issues: ${critical.length}\n`;
            report += `- Warnings: ${warning.length}\n`;
            report += `- Healthy Services: ${allMetrics.filter(m => m.status === 'normal').length}\n`;
            report += `- Average Quality Score: ${Math.round(allMetrics.reduce((s,m)=>s+(m.quality||0),0)/allMetrics.length)}%\n\n`;
            if (critical.length > 0) {
                report += `🔴 CRITICAL ISSUES (Immediate Attention Required)\n`;
                report += `${'-'.repeat(40)}\n`;
                critical.forEach(m => { report += `• ${m.service} (${m.region}): ${m.rtt}ms RTT, ${m.packet_loss}% loss\n`; });
                report += `\n`;
            }
            if (warning.length > 0) {
                report += `🟡 WARNINGS (Investigation Recommended)\n`;
                report += `${'-'.repeat(40)}\n`;
                warning.forEach(m => { report += `• ${m.service} (${m.region}): ${m.rtt}ms RTT, ${m.packet_loss}% loss\n`; });
                report += `\n`;
            }
            report += `✅ RECOMMENDATIONS\n`;
            report += `${'-'.repeat(40)}\n`;
            if (critical.length > 0) {
                report += `1. Investigate connectivity to critical services\n2. Check firewall rules and routing tables\n3. Contact upstream providers for transit issues\n`;
            } else if (warning.length > 0) {
                report += `1. Monitor warning services for potential degradation\n2. Review bandwidth utilization patterns\n`;
            } else {
                report += `1. Network is operating normally\n2. Continue regular monitoring\n`;
            }
            const blob = new Blob([report], { type: 'text/plain' });
            const link = document.createElement('a');
            link.href = URL.createObjectURL(blob);
            link.download = `hod_report_${new Date().toISOString().slice(0,19)}.txt`;
            link.click();
        }
        
        loadData();
        setInterval(loadData, 30000);
    </script>
</body>
</html>
HTEOF

# ================================================================
# SETUP CRON AND PERMISSIONS
# ================================================================
sudo chmod +x /opt/mcore-nms/collector.py
sudo python3 /opt/mcore-nms/collector.py

(crontab -l 2>/dev/null | grep -v "collector.py"; echo "*/5 * * * * /usr/bin/python3 /opt/mcore-nms/collector.py >> /var/log/mcnms/collector.log 2>&1") | crontab -

sudo chown -R www-data:www-data /var/www/html/mcnms
sudo chmod -R 755 /var/www/html/mcnms
sudo systemctl restart apache2

echo ""
echo "========================================="
echo "✅ MCORENMS PRO - FINAL COMPLETE DEPLOYMENT"
echo "========================================="
echo ""
echo "Total Services: ${#ALL_SERVICES[@]} (38 Existing + $(echo "$GLOBAL_SITES" | wc -l) Global)"
echo ""
echo "🌐 Access Dashboard: http://$DETECTED_DOMAIN/mcnms/"
echo "📊 Smokeping: http://$DETECTED_DOMAIN/smokeping/smokeping.cgi"
echo ""
echo "========================================="
EOF

# Execute final deployment
bash /tmp/mcnms-final-complete.sh