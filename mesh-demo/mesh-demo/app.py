#!/usr/bin/env python3
"""
Mesh Demo App - Cross-Namespace Communication Test
Each app calls all other apps and displays results.
"""

import os
import socket
import urllib.request
import urllib.error
import json
from datetime import datetime, timezone
from flask import Flask, jsonify

app = Flask(__name__)

APP_NAME = os.environ.get("APP_NAME", "unknown")
APP_NAMESPACE = os.environ.get("APP_NAMESPACE", "unknown")
APP_PORT = int(os.environ.get("APP_PORT", "8080"))
OTHER_APPS_JSON = os.environ.get("OTHER_APPS", "[]")
OTHER_APPS = json.loads(OTHER_APPS_JSON)

# Local hostname resolution for k8s cluster DNS
def get_pod_ip():
    """Get the pod's own IP address."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.41.0.1", 80))  # arbitrary k8s cluster IP
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip

POD_IP = get_pod_ip()
START_TIME = datetime.now(timezone.utc).isoformat()

@app.route("/")
def index():
    """Main page showing cross-namespace call results."""
    results = []
    for other in OTHER_APPS:
        host = other["host"]
        name = other["name"]
        namespace = other["namespace"]
        status = call_service(host, name)
        results.append({
            "app": name,
            "namespace": namespace,
            "host": host,
            "status": status["status"],
            "app_name": status.get("app_name", "N/A"),
            "app_namespace": status.get("app_namespace", "N/A"),
            "pod_ip": status.get("pod_ip", "N/A"),
            "latency_ms": status.get("latency_ms", 0),
            "error": status.get("error", ""),
            "timestamp": status.get("timestamp", ""),
        })
    
    html = f"""<!DOCTYPE html>
<html lang="zh-TW">
<head>
<meta charset="UTF-8">
<title>{APP_NAME} - 網格測試</title>
<style>
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #0f172a; color: #e2e8f0; }}
  h1 {{ color: #38bdf8; border-bottom: 2px solid #1e40af; padding-bottom: 10px; }}
  .info {{ display: flex; gap: 20px; margin: 15px 0; flex-wrap: wrap; }}
  .info-card {{ background: #1e293b; padding: 12px 18px; border-radius: 8px; border-left: 4px solid #38bdf8; }}
  .info-card label {{ color: #94a3b8; font-size: 12px; display: block; }}
  .info-card span {{ font-size: 16px; font-weight: bold; }}
  table {{ width: 100%; border-collapse: collapse; margin-top: 20px; background: #1e293b; border-radius: 8px; overflow: hidden; }}
  th {{ background: #1e40af; color: white; padding: 12px 10px; text-align: left; font-size: 13px; }}
  td {{ padding: 10px; border-bottom: 1px solid #334155; font-size: 13px; }}
  tr:last-child td {{ border-bottom: none; }}
  .ok {{ color: #4ade80; font-weight: bold; }}
  .fail {{ color: #f87171; font-weight: bold; }}
  .latency {{ color: #fbbf24; }}
  .footer {{ margin-top: 30px; color: #64748b; font-size: 12px; text-align: center; }}
</style>
</head>
<body>
<h1>{APP_NAME} 🏠 (NS: {APP_NAMESPACE})</h1>
<div class="info">
  <div class="info-card"><label>Pod IP</label><span>{POD_IP}</span></div>
  <div class="info-card"><label>Start Time</label><span>{START_TIME}</span></div>
  <div class="info-card"><label>Requests Received</label><span>{results_total()}</span></div>
</div>
<h2 style="color:#94a3b8;">Cross-Namespace Calls</h2>
<table>
<tr>
  <th>Target App</th>
  <th>Namespace</th>
  <th>Status</th>
  <th>Response</th>
  <th>Latency</th>
  <th>Error</th>
</tr>
"""
    for r in results:
        status_class = "ok" if r["status"] == 200 else "fail"
        status_text = "OK" if r["status"] == 200 else f"ERR {r['status']}"
        latency_str = f"{r['latency_ms']:.0f}ms" if r["latency_ms"] > 0 else "-"
        error_str = r["error"] if r["error"] else "-"
        resp = f'{r["app_name"]} (NS:{r["app_namespace"]})' if r["status"] == 200 else "-"
        html += f"""<tr>
  <td>{r["app"]}</td>
  <td>{r["namespace"]}</td>
  <td class="{status_class}">{status_text}</td>
  <td>{resp}</td>
  <td class="latency">{latency_str}</td>
  <td style="color:#f87171;">{error_str}</td>
</tr>
"""
    html += """</table>
<div class="footer">Mesh Demo — Verifying Cross-Namespace Communication</div>
</body>
</html>"""
    return html, 200

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "app": APP_NAME,
        "namespace": APP_NAMESPACE,
        "pod_ip": POD_IP,
        "uptime_since": START_TIME,
    })

@app.route("/metrics")
def metrics():
    return jsonify({"app": APP_NAME, "namespace": APP_NAMESPACE, "calls": results_total()})

def call_service(host, name):
    """Call another app's health endpoint and return result."""
    url = f"http://{host}/health"
    start = datetime.now(timezone.utc)
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            end = datetime.now(timezone.utc)
            latency = (end - start).total_seconds() * 1000
            return {
                "status": resp.status,
                "app_name": data.get("app", name),
                "app_namespace": data.get("namespace", "unknown"),
                "pod_ip": data.get("pod_ip", "unknown"),
                "latency_ms": latency,
                "timestamp": data.get("uptime_since", ""),
            }
    except urllib.error.HTTPError as e:
        end = datetime.now(timezone.utc)
        latency = (end - start).total_seconds() * 1000
        return {"status": e.code, "latency_ms": latency, "error": str(e)}
    except urllib.error.URLError as e:
        end = datetime.now(timezone.utc)
        latency = (end - start).total_seconds() * 1000
        return {"status": 0, "latency_ms": latency, "error": str(e.reason)}
    except Exception as e:
        end = datetime.now(timezone.utc)
        latency = (end - start).total_seconds() * 1000
        return {"status": 0, "latency_ms": latency, "error": str(e)}

# Track total requests
request_count = 0

def results_total():
    global request_count
    request_count += 1
    return request_count

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=APP_PORT)
