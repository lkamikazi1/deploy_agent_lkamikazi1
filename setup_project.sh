#!/bin/bash

interrupt_cleanup() {
	echo "..."
	echo "Detected interruption! archive and clean up going thru..."

	ArchiveName="attendance_tracker_${input}_archive"

	tar -czf "${ArchiveName}.tar.gz" "$Project_IaC" 2>/dev/null
	rm -rf "$Project_IaC"

	echo "Archive save as: ${ArchiveName}.tar.gz"
	echo "Incomplete directory removed"
	exit 1
}

trap interrupt_cleanup SIGINT

read -p "Enter project name: " input

Project_IaC="attendance_tracker_${input}"

echo "Project structure built in $Project_IaC"

mkdir -p "$Project_IaC/Helpers"
mkdir -p "$Project_IaC/reports"

cat > "$Project_IaC/attendance_checker.py" <<EOF 
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)
    
    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']
        
        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")
        
        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])
            
            # Simple Math: (Attended / Total) * 100
            attendance_pct = (attended / total_sessions) * 100
            
            message = ""
            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."
            
            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()

EOF

cat > "$Project_IaC/Helpers/assets.csv" <<EOF

Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0

EOF

cat > "$Project_IaC/Helpers/config.json" <<EOF

{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}

EOF

cat > "$Project_IaC/reports/reports.log" <<EOF

--- Attendance Report Run: 2026-02-06 18:10:01.468726 ---
[2026-02-06 18:10:01.469363] ALERT SENT TO bob@example.com: URGENT: Bob Smith, your
attendance is 46.7%. You will fail this class.
[2026-02-06 18:10:01.469424] ALERT SENT TO charlie@example.com: URGENT: Charlie
Davis, your attendance is 26.7%. You will fail this class.

EOF 

echo "Directory structure complete"

cat > "$Project_IaC/Helpers/config.json" <<EOF
{
"warning: 75,
failure: 50
}
EOF

read -p "Want to update attendance? (YES/NO): " update

if [ "$update" = "YES" ]; then
	read -p "Enter new warning threshold (dafault 75): " warn
	read -p "Enter new failure threshold (default 50): " fail

	sed -i "s/\"warning\": [0-9]*/\"warning\": $warn/" "$Project_IaC/Helpers/config.json"
	sed -i "s/\"failure\": [0-9]*/\"failure\": $fail/" "$Project_IaC/Helpers/config.json"

	echo "Update done"
	echo "New config:"
	cat  "$Project_IaC/Helpers/config.json"

else

	echo "Keeping the dafaults"

fi

echo "Health check running..."

if command -v python3 &>/dev/null; then
	echo "Installation done: $(python3 --version)"
else
	echo "Issue: Install python3 first before procceding"
fi

echo "Directory structure confirmed"

for track in \
	"$Project_IaC/attendance_checker.py" \
	"$Project_IaC/Helpers/assets.csv" \
	"$Project_IaC/Helpers/config.json" \
	"$Project_IaC/reports/reports.log"
do 
	if [ -f "$track" ]; then
		echo " Done $track"
	else
		echo " Missing: $track"
	fi
done

echo "...Setup complete..."
