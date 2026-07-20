#!/bin/bash
# mesh-monitor.sh — Continuously monitor cross-namespace mesh connectivity
# Usage: ./mesh-monitor.sh
# Press Ctrl+C to stop

URLS=(
  "https://app1.luban.paulhome.local"
  "https://app2.luban.paulhome.local"
  "https://app3.luban.paulhome.local"
  "https://app4.luban.paulhome.local"
  "https://app5.luban.paulhome.local"
)

APP_NAMES=("App 1" "App 2" "App 3" "App 4" "App 5")

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Mesh Demo Cross-Namespace Connectivity Monitor     ║${NC}"
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
      
      # Use Python to parse HTML table rows cleanly
      curl -sk "$URL" 2>/dev/null | python3 -c "
import sys, re
html = sys.stdin.read()
# Find all <tr>...</tr> blocks between Cross-Namespace Calls and </table>
rows = re.findall(r'<tr>(.*?)</tr>', html, re.DOTALL)
# Skip header row (contains <th>)
data_rows = [r for r in rows if '<th>' not in r]
for row in data_rows:
    tds = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
    if len(tds) >= 6:
        target = tds[0].strip()
        ns = tds[1].strip()
        status_raw = tds[2].strip()
        latency = tds[4].strip()
        error = tds[5].strip()
        
        status_ok = 'ok' in tds[2].lower()
        status_text = 'OK' if status_ok else 'FAIL'
        color = '\033[0;32m' if status_ok else '\033[0;31m'
        
        lat_display = latency if latency else '-'
        err_display = error if error else '-'
        
        print(f'  │  {target:<6} → {ns:<15} {color}{status_text}{chr(27)}[0m  {lat_display:<8} {err_display}')
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
