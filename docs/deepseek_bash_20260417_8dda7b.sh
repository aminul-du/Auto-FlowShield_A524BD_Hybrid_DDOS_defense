#!/bin/bash
echo "========================================="
echo "MCoreNMS Pro - STATIC HTML SOLUTION"
echo "========================================="

# Step 1: Create a simple data collector that outputs HTML directly
sudo tee /opt/mcore-nms/generate_dashboard.sh << 'EOF'
#!/bin/bash
# This script runs every 5 minutes and generates a static HTML file

DATA_FILE="/var/www/html/mcnms.html"
LOG_FILE="/var/log/mcnms-collector.log"

echo "Generating dashboard at $(date)" >> $LOG_FILE

# Function to test TCP connection
test_tcp() {
    timeout 3 bash -c "echo >/dev/tcp/$1/$2" 2>/dev/null
    if [ $? -eq 0 ]; then
        # Measure RTT using time command
        RTT=$(timeout 5 bash -c "time (echo >/dev/tcp/$1/$2) 2>&1" | grep real | awk '{print $2}' | sed 's/0m//g' | sed 's/s//g' | awk '{print $1 * 1000}')
        echo "${RTT%.*}"
    else
        echo "FAILED"
    fi
}

# Collect metrics
WHATSAPP_RTT=$(test_tcp "whatsapp.com" 443)
IMO_RTT=$(test_tcp "imo.im" 443)
GOOGLE_RTT=$(test_tcp "google.com" 443)
BIGO_SG_RTT=$(test_tcp "45.249.47.148" 443)
BIGO_MUMBAI_RTT=$(test_tcp "164.90.73.0" 443)
BIGO_DHAKA_RTT=$(test_tcp "164.90.84.180" 443)

# Generate HTML
cat > $DATA_FILE << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>MCoreNMS Pro - Network Monitor</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="30">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #f0f2f5; padding: 20px; }
        .header { background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); color: white; padding: 25px; border-radius: 12px; margin-bottom: 25px; }
        .header h1 { font-size: 28px; margin-bottom: 8px; }
        .project-id { font-family: monospace; font-size: 12px; opacity: 0.8; margin-top: 5px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 20px; margin-bottom: 25px; }
        .stat-card { background: white; padding: 20px; border-radius: 12px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .stat-number { font-size: 36px; font-weight: bold; }
        .stat-label { color: #666; margin-top: 5px; font-size: 14px; }
        .card { background: white; border-radius: 12px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .card h3 { margin-bottom: 15px; color: #1a1a2e; border-left: 4px solid #e94560; padding-left: 15px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #1a1a2e; color: white; font-weight: 600; }
        tr:hover { background: #f5f5f5; }
        .normal { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .critical { color: #dc3545; font-weight: bold; }
        .badge { display: inline-block; padding: 4px 12px; border-radius: 20px; color: white; font-size: 12px; font-weight: bold; }
        .badge-normal { background: #28a745; }
        .badge-warning { background: #ffc107; color: #333; }
        .badge-critical { background: #dc3545; }
        .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; border-top: 1px solid #ddd; margin-top: 20px; }
        .last-update { text-align: right; font-size: 12px; color: #666; margin-bottom: 15px; }
        .refresh-info { background: #e8f4f8; padding: 10px; border-radius: 8px; text-align: center; margin-bottom: 20px; font-size: 14px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📡 MCoreNMS Pro</h1>
        <div class="project-id">Project ID: MeticulousCoreNMS@42026V1 | Owner: Meticulous Core Global</div>
    </div>

HTMLEOF

# Add dynamic data
cat >> $DATA_FILE << EOF
    <div class="refresh-info">
        🔄 Page auto-refreshes every 30 seconds | Data collected every 5 minutes
    </div>
    
    <div class="stats">
        <div class="stat-card">
            <div class="stat-number">6</div>
            <div class="stat-label">Total Monitors</div>
        </div>
        <div class="stat-card">
            <div class="stat-number" style="color:#28a745">$(echo "$WHATSAPP_RTT $IMO_RTT $GOOGLE_RTT" | grep -o '[0-9]*' | wc -l)</div>
            <div class="stat-label">Healthy</div>
        </div>
        <div class="stat-card">
            <div class="stat-number" style="color:#ffc107">0</div>
            <div class="stat-label">Warning</div>
        </div>
        <div class="stat-card">
            <div class="stat-number" style="color:#dc3545">$(echo "$WHATSAPP_RTT $IMO_RTT $GOOGLE_RTT $BIGO_SG_RTT $BIGO_MUMBAI_RTT $BIGO_DHAKA_RTT" | grep -c "FAILED")</div>
            <div class="stat-label">Critical</div>
        </div>
    </div>
    
    <div class="card">
        <h3>📊 Network Performance Metrics</h3>
        <div class="last-update">Last updated: $(date '+%Y-%m-%d %H:%M:%S')</div>
        <table>
            <thead>
                <tr><th>Service</th><th>Region</th><th>Host</th><th>RTT (ms)</th><th>Status</th></tr>
            </thead>
            <tbody>
                <tr>
                    <td><strong>WhatsApp</strong></td>
                    <td>Global</td>
                    <td>whatsapp.com:443</td>
                    <td class="$(echo $WHATSAPP_RTT | grep -q 'FAILED' && echo 'critical' || (echo $WHATSAPP_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $WHATSAPP_RTT)</td>
                    <td><span class="badge badge-$(echo $WHATSAPP_RTT | grep -q 'FAILED' && echo 'critical' || (echo $WHATSAPP_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $WHATSAPP_RTT | grep -q 'FAILED' && echo 'CRITICAL' || (echo $WHATSAPP_RTT | awk '{if($1>100) print "WARNING"; else print "NORMAL"}'))</span></td>
                </tr>
                <tr>
                    <td><strong>IMO</strong></td>
                    <td>Global</td>
                    <td>imo.im:443</td>
                    <td class="$(echo $IMO_RTT | grep -q 'FAILED' && echo 'critical' || (echo $IMO_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $IMO_RTT)</td>
                    <td><span class="badge badge-$(echo $IMO_RTT | grep -q 'FAILED' && echo 'critical' || (echo $IMO_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $IMO_RTT | grep -q 'FAILED' && echo 'CRITICAL' || (echo $IMO_RTT | awk '{if($1>100) print "WARNING"; else print "NORMAL"}'))</span></td>
                </tr>
                <tr>
                    <td><strong>Google</strong></td>
                    <td>Global</td>
                    <td>google.com:443</td>
                    <td class="$(echo $GOOGLE_RTT | grep -q 'FAILED' && echo 'critical' || (echo $GOOGLE_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $GOOGLE_RTT)</td>
                    <td><span class="badge badge-$(echo $GOOGLE_RTT | grep -q 'FAILED' && echo 'critical' || (echo $GOOGLE_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $GOOGLE_RTT | grep -q 'FAILED' && echo 'CRITICAL' || (echo $GOOGLE_RTT | awk '{if($1>100) print "WARNING"; else print "NORMAL"}'))</span></td>
                </tr>
                <tr>
                    <td><strong>BIGO Live</strong></td>
                    <td>Singapore</td>
                    <td>45.249.47.148:443</td>
                    <td class="$(echo $BIGO_SG_RTT | grep -q 'FAILED' && echo 'critical' || (echo $BIGO_SG_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $BIGO_SG_RTT)</td>
                    <td><span class="badge badge-$(echo $BIGO_SG_RTT | grep -q 'FAILED' && echo 'critical' || (echo $BIGO_SG_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $BIGO_SG_RTT | grep -q 'FAILED' && echo 'CRITICAL' || (echo $BIGO_SG_RTT | awk '{if($1>100) print "WARNING"; else print "NORMAL"}'))</span></td>
                </tr>
                <tr>
                    <td><strong>BIGO Live</strong></td>
                    <td>Mumbai</td>
                    <td>164.90.73.0:443</td>
                    <td class="$(echo $BIGO_MUMBAI_RTT | grep -q 'FAILED' && echo 'critical' || (echo $BIGO_MUMBAI_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $BIGO_MUMBAI_RTT)</td>
                    <td><span class="badge badge-$(echo $BIGO_MUMBAI_RTT | grep -q 'FAILED' && echo 'critical' || (echo $BIGO_MUMBAI_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $BIGO_MUMBAI_RTT | grep -q 'FAILED' && echo 'CRITICAL' || (echo $BIGO_MUMBAI_RTT | awk '{if($1>100) print "WARNING"; else print "NORMAL"}'))</span></td>
                </tr>
                <tr>
                    <td><strong>BIGO Live</strong></td>
                    <td>Dhaka</td>
                    <td>164.90.84.180:443</td>
                    <td class="$(echo $BIGO_DHAKA_RTT | grep -q 'FAILED' && echo 'critical' || (echo $BIGO_DHAKA_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $BIGO_DHAKA_RTT)</td>
                    <td><span class="badge badge-$(echo $BIGO_DHAKA_RTT | grep -q 'FAILED' && echo 'critical' || (echo $BIGO_DHAKA_RTT | awk '{if($1>100) print "warning"; else print "normal"}'))">$(echo $BIGO_DHAKA_RTT | grep -q 'FAILED' && echo 'CRITICAL' || (echo $BIGO_DHAKA_RTT | awk '{if($1>100) print "WARNING"; else print "NORMAL"}'))</span></td>
                </tr>
            </tbody>
        </table>
    </div>
    
    <div class="footer">
        <p>MCoreNMS Pro v2.0 | Monitoring WhatsApp | IMO | BIGO | Google</p>
        <p>Data collected every 5 minutes via cron job | Page auto-refreshes every 30 seconds</p>
    </div>
</body>
</html>
EOF

echo "Dashboard generated at $(date)" >> $LOG_FILE
echo "Done - Dashboard saved to $DATA_FILE" >> $LOG_FILE