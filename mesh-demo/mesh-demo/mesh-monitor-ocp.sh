#!/bin/bash
# mesh-monitor-ocp.sh — Monitor mesh-demo apps on OCP via Istio Gateway
# URLs: https://app{1-5}.devops.local (through OCP ingress + Istio)

URLS=(
  "https://app1.devops.local"
  "https://app2.devops.local"
  "https://app3.devops.local"
  "https://app4.devops.local"
  "https://app5.devops.local"
)

APP_NAMES=("App 1" "App 2" "App 3" "App 4" "App 5")

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Mesh Demo OCP Monitor (Istio Gateway)              ║${NC}"
echo -e "${CYAN}║  Press Ctrl+C to stop                               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

while true; do
  printf "\033[H\033[2J"
  
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  ALL_OK=true
  
  for i in "${!URLS[@]}"; do
    URL="${URLS[$i]}"
    NAME="${APP_NAMES[$i]}"
    
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
      echo -e "${GREEN}  ┌── ${NAME}${NC}"
      
      curl -sk "$URL" 2>/dev/null | python3 -c "
import sys, re
html = sys.stdin.read()
rows = re.findall(r'<tr>(.*?)</tr>', html, re.DOTALL)
data_rows = [r for r in rows if '<th>' not in r]
for row in data_rows:
    tds = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
    if len(tds) >= 6:
        target = tds[0].strip()
        ns = tds[1].strip()
        status_ok = 'ok' in tds[2].lower()
        status_text = 'OK' if status_ok else 'FAIL'
        color = '\033[0;32m' if status_ok else '\033[0;31m'
        latency = tds[4].strip() if tds[4].strip() else '-'
        error = tds[5].strip() if tds[5].strip() else '-'
        print(f'  │  {target:<6} → {ns:<15} {color}{status_text}{chr(27)}[0m  {latency:<8} {error}')
"
      echo -e "${GREEN}  └───────────────────────────────────────────────────────${NC}"
    else
      echo -e "${RED}  ┌── ${NAME} [HTTP ${HTTP_CODE}]${NC}"
      echo -e "${RED}  │  UNREACHABLE${NC}"
      echo -e "${RED}  └───────────────────────────────────────────────────────${NC}"
      ALL_OK=false
    fi
  done
  
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if $ALL_OK; then
    echo -e "${GREEN}  Status: ALL HEALTHY — Mesh connectivity verified${NC}"
  else
    echo -e "${RED}  Status: DEGRADED — Some endpoints unreachable${NC}"
  fi
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  sleep 2
done
