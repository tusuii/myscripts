#!/bin/bash

# SonarQube Scanner Report Generator
# Usage: ./sonar-report-generator.sh <project-key> <sonar-url> <sonar-token> [email]

set -e

# Configuration
PROJECT_KEY="$1"
SONAR_URL="$2"
SONAR_TOKEN="$3"
EMAIL="$4"
REPORT_DIR="sonar-reports"
DATE=$(date +%Y%m%d_%H%M%S)

# Validate inputs
if [ $# -lt 3 ]; then
    echo "Usage: $0 <project-key> <sonar-url> <sonar-token> [email]"
    echo "Example: $0 my-project http://localhost:9000 squ_token123 team@company.com"
    exit 1
fi

echo "🚀 Starting SonarQube analysis and report generation..."

# Create report directory
mkdir -p $REPORT_DIR

# 1. Run SonarQube Scanner
echo "📊 Running SonarQube scan..."
sonar-scanner \
  -Dsonar.projectKey=$PROJECT_KEY \
  -Dsonar.sources=. \
  -Dsonar.host.url=$SONAR_URL \
  -Dsonar.token=$SONAR_TOKEN \
  -Dsonar.exclusions="**/node_modules/**,**/target/**,**/*.test.*,**/vendor/**"

# Wait for analysis to complete
echo "⏳ Waiting for analysis to complete..."
sleep 20

# 2. Fetch project data
echo "📥 Fetching project data..."
curl -s -u $SONAR_TOKEN: \
  "$SONAR_URL/api/measures/component?component=$PROJECT_KEY&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,ncloc,sqale_index" \
  -o "$REPORT_DIR/metrics.json"

curl -s -u $SONAR_TOKEN: \
  "$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&severities=BLOCKER,CRITICAL&ps=100" \
  -o "$REPORT_DIR/issues.json"

# 3. Generate HTML Report
echo "📄 Generating HTML report..."
cat > "$REPORT_DIR/sonar-report-$DATE.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>SonarQube Analysis Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; }
        .header { background: linear-gradient(135deg, #4CAF50, #45a049); color: white; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 2.5em; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; padding: 30px; }
        .metric { background: white; border-radius: 8px; padding: 20px; text-align: center; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .metric h3 { margin: 0 0 10px 0; color: #333; font-size: 0.9em; text-transform: uppercase; }
        .metric .value { font-size: 2.5em; font-weight: bold; margin: 10px 0; }
        .bugs .value { color: #f44336; }
        .vulnerabilities .value { color: #ff9800; }
        .code-smells .value { color: #2196F3; }
        .coverage .value { color: #4CAF50; }
        .duplications .value { color: #9C27B0; }
        .lines .value { color: #607D8B; }
        .debt .value { color: #795548; }
        .summary { padding: 30px; background: #fafafa; }
        .summary h2 { color: #333; margin-bottom: 20px; }
        .quality-gate { padding: 20px; margin: 20px 0; border-radius: 8px; text-align: center; }
        .quality-gate.passed { background: #e8f5e8; border: 2px solid #4CAF50; color: #2e7d32; }
        .quality-gate.failed { background: #ffebee; border: 2px solid #f44336; color: #c62828; }
        .footer { background: #333; color: white; padding: 20px; text-align: center; }
        .footer a { color: #4CAF50; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>SonarQube Analysis Report</h1>
            <p>PROJECT_PLACEHOLDER | DATE_PLACEHOLDER</p>
        </div>
        
        <div class="metrics">
            <div class="metric bugs">
                <h3>Bugs</h3>
                <div class="value">BUGS_PLACEHOLDER</div>
            </div>
            <div class="metric vulnerabilities">
                <h3>Vulnerabilities</h3>
                <div class="value">VULNERABILITIES_PLACEHOLDER</div>
            </div>
            <div class="metric code-smells">
                <h3>Code Smells</h3>
                <div class="value">CODE_SMELLS_PLACEHOLDER</div>
            </div>
            <div class="metric coverage">
                <h3>Coverage</h3>
                <div class="value">COVERAGE_PLACEHOLDER%</div>
            </div>
            <div class="metric duplications">
                <h3>Duplications</h3>
                <div class="value">DUPLICATIONS_PLACEHOLDER%</div>
            </div>
            <div class="metric lines">
                <h3>Lines of Code</h3>
                <div class="value">LINES_PLACEHOLDER</div>
            </div>
        </div>
        
        <div class="summary">
            <h2>Summary</h2>
            <div class="quality-gate QUALITY_STATUS_PLACEHOLDER">
                <h3>Quality Gate: QUALITY_TEXT_PLACEHOLDER</h3>
            </div>
            <p><strong>Analysis Date:</strong> FULL_DATE_PLACEHOLDER</p>
            <p><strong>Project Key:</strong> PROJECT_PLACEHOLDER</p>
        </div>
        
        <div class="footer">
            <p>Generated by SonarQube Scanner | <a href="SONAR_URL_PLACEHOLDER/dashboard?id=PROJECT_PLACEHOLDER">View Full Report</a></p>
        </div>
    </div>
</body>
</html>
EOF

# 4. Parse JSON and populate HTML
echo "🔄 Processing metrics..."
if command -v jq >/dev/null 2>&1; then
    # Use jq if available
    BUGS=$(jq -r '.component.measures[] | select(.metric=="bugs") | .value // "0"' "$REPORT_DIR/metrics.json")
    VULNERABILITIES=$(jq -r '.component.measures[] | select(.metric=="vulnerabilities") | .value // "0"' "$REPORT_DIR/metrics.json")
    CODE_SMELLS=$(jq -r '.component.measures[] | select(.metric=="code_smells") | .value // "0"' "$REPORT_DIR/metrics.json")
    COVERAGE=$(jq -r '.component.measures[] | select(.metric=="coverage") | .value // "0"' "$REPORT_DIR/metrics.json")
    DUPLICATIONS=$(jq -r '.component.measures[] | select(.metric=="duplicated_lines_density") | .value // "0"' "$REPORT_DIR/metrics.json")
    LINES=$(jq -r '.component.measures[] | select(.metric=="ncloc") | .value // "0"' "$REPORT_DIR/metrics.json")
else
    # Fallback parsing without jq
    BUGS=$(grep -o '"metric":"bugs"[^}]*"value":"[^"]*"' "$REPORT_DIR/metrics.json" | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "0")
    VULNERABILITIES=$(grep -o '"metric":"vulnerabilities"[^}]*"value":"[^"]*"' "$REPORT_DIR/metrics.json" | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "0")
    CODE_SMELLS=$(grep -o '"metric":"code_smells"[^}]*"value":"[^"]*"' "$REPORT_DIR/metrics.json" | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "0")
    COVERAGE=$(grep -o '"metric":"coverage"[^}]*"value":"[^"]*"' "$REPORT_DIR/metrics.json" | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "0")
    DUPLICATIONS=$(grep -o '"metric":"duplicated_lines_density"[^}]*"value":"[^"]*"' "$REPORT_DIR/metrics.json" | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "0")
    LINES=$(grep -o '"metric":"ncloc"[^}]*"value":"[^"]*"' "$REPORT_DIR/metrics.json" | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "0")
fi

# Determine quality gate status
TOTAL_ISSUES=$((${BUGS:-0} + ${VULNERABILITIES:-0}))
if [ "$TOTAL_ISSUES" -eq 0 ]; then
    QUALITY_STATUS="passed"
    QUALITY_TEXT="PASSED"
else
    QUALITY_STATUS="failed"
    QUALITY_TEXT="FAILED"
fi

# Replace placeholders in HTML
sed -i "s/PROJECT_PLACEHOLDER/$PROJECT_KEY/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/DATE_PLACEHOLDER/$(date +%Y-%m-%d)/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/FULL_DATE_PLACEHOLDER/$(date)/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/BUGS_PLACEHOLDER/${BUGS:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/VULNERABILITIES_PLACEHOLDER/${VULNERABILITIES:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/CODE_SMELLS_PLACEHOLDER/${CODE_SMELLS:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/COVERAGE_PLACEHOLDER/${COVERAGE:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/DUPLICATIONS_PLACEHOLDER/${DUPLICATIONS:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/LINES_PLACEHOLDER/${LINES:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/QUALITY_STATUS_PLACEHOLDER/$QUALITY_STATUS/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/QUALITY_TEXT_PLACEHOLDER/$QUALITY_TEXT/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s|SONAR_URL_PLACEHOLDER|$SONAR_URL|g" "$REPORT_DIR/sonar-report-$DATE.html"

# 5. Generate PDF Report
echo "📑 Generating PDF report..."
if command -v wkhtmltopdf >/dev/null 2>&1; then
    wkhtmltopdf --page-size A4 --orientation Portrait --margin-top 0.75in --margin-right 0.75in --margin-bottom 0.75in --margin-left 0.75in \
        "$REPORT_DIR/sonar-report-$DATE.html" "$REPORT_DIR/sonar-report-$DATE.pdf"
    echo "✅ PDF report generated: $REPORT_DIR/sonar-report-$DATE.pdf"
else
    echo "⚠️  wkhtmltopdf not found. Install with: sudo apt install wkhtmltopdf"
fi

# 6. Send Email (if provided)
if [ -n "$EMAIL" ]; then
    echo "📧 Sending email report..."
    if command -v mail >/dev/null 2>&1; then
        SUBJECT="SonarQube Report - $PROJECT_KEY ($(date +%Y-%m-%d))"
        BODY="SonarQube analysis completed for project: $PROJECT_KEY

Summary:
- Bugs: ${BUGS:-0}
- Vulnerabilities: ${VULNERABILITIES:-0}
- Code Smells: ${CODE_SMELLS:-0}
- Coverage: ${COVERAGE:-0}%

View full report: $SONAR_URL/dashboard?id=$PROJECT_KEY

Reports attached."

        if [ -f "$REPORT_DIR/sonar-report-$DATE.pdf" ]; then
            echo "$BODY" | mail -s "$SUBJECT" -A "$REPORT_DIR/sonar-report-$DATE.pdf" -A "$REPORT_DIR/sonar-report-$DATE.html" "$EMAIL"
        else
            echo "$BODY" | mail -s "$SUBJECT" -A "$REPORT_DIR/sonar-report-$DATE.html" "$EMAIL"
        fi
        echo "✅ Email sent to: $EMAIL"
    else
        echo "⚠️  Mail command not found. Install with: sudo apt install mailutils"
    fi
fi

# 7. Summary
echo ""
echo "🎉 Report generation completed!"
echo "📁 Reports saved in: $REPORT_DIR/"
echo "🌐 HTML Report: $REPORT_DIR/sonar-report-$DATE.html"
if [ -f "$REPORT_DIR/sonar-report-$DATE.pdf" ]; then
    echo "📄 PDF Report: $REPORT_DIR/sonar-report-$DATE.pdf"
fi
echo "🔗 Online Report: $SONAR_URL/dashboard?id=$PROJECT_KEY"
echo ""
echo "📊 Quick Summary:"
echo "   Bugs: ${BUGS:-0}"
echo "   Vulnerabilities: ${VULNERABILITIES:-0}"
echo "   Code Smells: ${CODE_SMELLS:-0}"
echo "   Coverage: ${COVERAGE:-0}%"
echo "   Quality Gate: $QUALITY_TEXT"
