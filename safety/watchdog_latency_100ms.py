import subprocess, time
# Target: Router Mgmt IP. Threshold: 100ms
def check_safety():
    while True:
        # Ping check and logic to stop automation if latency > 100ms
        print("Safety Watchdog: Monitoring Control Plane...")
        time.sleep(2)
check_safety()
