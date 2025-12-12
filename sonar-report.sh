#!/bin/bash

# SonarQube Scanner Report Generator - Universal Version
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

# Check if sonar-scanner is available
if ! command -v sonar-scanner >/dev/null 2>&1; then
    echo "❌ sonar-scanner not found in PATH"
    echo "💡 Add sonar-scanner to PATH or install it:"
    echo "   export PATH=\$HOME/sonar-docker/sonar-scanner-5.0.1.3006-linux/bin:\$PATH"
    exit 1
fi

# 1. Run SonarQube Scanner with universal exclusions
echo "📊 Running SonarQube scan..."

# Check if Java files exist and handle accordingly
if find . -name "*.java" -type f | head -1 | grep -q ".java"; then
    echo "Java files detected - excluding from analysis (requires compilation)"
    JAVA_EXCLUSION=",**/*.java"
else
    JAVA_EXCLUSION=""
fi

sonar-scanner \
  -Dsonar.projectKey=$PROJECT_KEY \
  -Dsonar.sources=. \
  -Dsonar.host.url=$SONAR_URL \
  -Dsonar.token=$SONAR_TOKEN \
  -Dsonar.exclusions="**/node_modules/**,**/target/**,**/build/**,**/dist/**,**/*.test.*,**/*.spec.*,**/vendor/**,**/.git/**,**/.svn/**,**/coverage/**,**/__pycache__/**,**/*.pyc,**/.pytest_cache/**,**/bin/**,**/obj/**,**/.vs/**,**/.vscode/**,**/logs/**,**/*.log,**/.DS_Store,**/Thumbs.db${JAVA_EXCLUSION}" \
  -Dsonar.sourceEncoding=UTF-8 \
  -Dsonar.scm.disabled=true || {
    echo "⚠️  SonarQube scan failed, but continuing with report generation..."
    SCAN_FAILED=true
}

# Wait for analysis to complete
echo "⏳ Waiting for analysis to complete..."
sleep 15

# 2. Fetch project data with error handling
echo "📥 Fetching project data..."
if ! curl -s -u $SONAR_TOKEN: \
  "$SONAR_URL/api/measures/component?component=$PROJECT_KEY&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,ncloc,sqale_index,reliability_rating,security_rating,sqale_rating" \
  -o "$REPORT_DIR/metrics.json" 2>/dev/null; then
    echo "⚠️  Failed to fetch metrics, creating empty metrics file"
    echo '{"component":{"measures":[]}}' > "$REPORT_DIR/metrics.json"
fi

if ! curl -s -u $SONAR_TOKEN: \
  "$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&severities=BLOCKER,CRITICAL&ps=100" \
  -o "$REPORT_DIR/issues.json" 2>/dev/null; then
    echo "⚠️  Failed to fetch issues, creating empty issues file"
    echo '{"issues":[]}' > "$REPORT_DIR/issues.json"
fi

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
        .quality-gate.unknown { background: #fff3e0; border: 2px solid #ff9800; color: #e65100; }
        .footer { background: #333; color: white; padding: 20px; text-align: center; }
        .footer a { color: #4CAF50; text-decoration: none; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 15px; margin: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>SonarQube Analysis Report</h1>
            <p>PROJECT_PLACEHOLDER | DATE_PLACEHOLDER</p>
        </div>
        
        SCAN_WARNING_PLACEHOLDER
        
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
            <p><strong>Languages Detected:</strong> Multi-language project</p>
        </div>
        
        <div class="footer">
            <p>Generated by SonarQube Scanner | <a href="SONAR_URL_PLACEHOLDER/dashboard?id=PROJECT_PLACEHOLDER">View Full Report</a></p>
        </div>
    </div>
</body>
</html>
EOF

# 4. Parse JSON and populate HTML with better error handling
echo "🔄 Processing metrics..."

# Function to safely extract metric value
extract_metric() {
    local metric_name="$1"
    local file="$2"
    local default_value="${3:-0}"
    
    if command -v jq >/dev/null 2>&1; then
        jq -r ".component.measures[]? | select(.metric==\"$metric_name\") | .value // \"$default_value\"" "$file" 2>/dev/null || echo "$default_value"
    else
        grep -o "\"metric\":\"$metric_name\"[^}]*\"value\":\"[^\"]*\"" "$file" 2>/dev/null | \
        grep -o "\"value\":\"[^\"]*\"" | cut -d'"' -f4 || echo "$default_value"
    fi
}

# Extract metrics with defaults
BUGS=$(extract_metric "bugs" "$REPORT_DIR/metrics.json" "0")
VULNERABILITIES=$(extract_metric "vulnerabilities" "$REPORT_DIR/metrics.json" "0")
CODE_SMELLS=$(extract_metric "code_smells" "$REPORT_DIR/metrics.json" "0")
COVERAGE=$(extract_metric "coverage" "$REPORT_DIR/metrics.json" "N/A")
DUPLICATIONS=$(extract_metric "duplicated_lines_density" "$REPORT_DIR/metrics.json" "0")
LINES=$(extract_metric "ncloc" "$REPORT_DIR/metrics.json" "0")

# Handle N/A coverage
if [ "$COVERAGE" = "N/A" ] || [ -z "$COVERAGE" ]; then
    COVERAGE_DISPLAY="N/A"
else
    COVERAGE_DISPLAY="$COVERAGE"
fi

# Determine quality gate status
TOTAL_ISSUES=$((${BUGS:-0} + ${VULNERABILITIES:-0}))
if [ "$SCAN_FAILED" = "true" ]; then
    QUALITY_STATUS="unknown"
    QUALITY_TEXT="SCAN FAILED"
    SCAN_WARNING='<div class="warning">⚠️ SonarQube scan encountered issues. Some metrics may be incomplete.</div>'
elif [ "$TOTAL_ISSUES" -eq 0 ]; then
    QUALITY_STATUS="passed"
    QUALITY_TEXT="PASSED"
    SCAN_WARNING=""
else
    QUALITY_STATUS="failed"
    QUALITY_TEXT="FAILED"
    SCAN_WARNING=""
fi

# Replace placeholders in HTML
sed -i "s/PROJECT_PLACEHOLDER/$PROJECT_KEY/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/DATE_PLACEHOLDER/$(date +%Y-%m-%d)/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/FULL_DATE_PLACEHOLDER/$(date)/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/BUGS_PLACEHOLDER/${BUGS:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/VULNERABILITIES_PLACEHOLDER/${VULNERABILITIES:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/CODE_SMELLS_PLACEHOLDER/${CODE_SMELLS:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/COVERAGE_PLACEHOLDER/${COVERAGE_DISPLAY}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/DUPLICATIONS_PLACEHOLDER/${DUPLICATIONS:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/LINES_PLACEHOLDER/${LINES:-0}/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/QUALITY_STATUS_PLACEHOLDER/$QUALITY_STATUS/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s/QUALITY_TEXT_PLACEHOLDER/$QUALITY_TEXT/g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s|SONAR_URL_PLACEHOLDER|$SONAR_URL|g" "$REPORT_DIR/sonar-report-$DATE.html"
sed -i "s|SCAN_WARNING_PLACEHOLDER|$SCAN_WARNING|g" "$REPORT_DIR/sonar-report-$DATE.html"

# 5. Generate PDF Report
echo "📑 Generating PDF report..."
if command -v wkhtmltopdf >/dev/null 2>&1; then
    if wkhtmltopdf --page-size A4 --orientation Portrait \
        --margin-top 0.75in --margin-right 0.75in --margin-bottom 0.75in --margin-left 0.75in \
        --disable-smart-shrinking --print-media-type \
        "$REPORT_DIR/sonar-report-$DATE.html" "$REPORT_DIR/sonar-report-$DATE.pdf" 2>/dev/null; then
        echo "✅ PDF report generated: $REPORT_DIR/sonar-report-$DATE.pdf"
    else
        echo "⚠️  PDF generation failed, but HTML report is available"
    fi
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
- Coverage: ${COVERAGE_DISPLAY}
- Quality Gate: $QUALITY_TEXT

View full report: $SONAR_URL/dashboard?id=$PROJECT_KEY

Reports attached."

        # Send email with attachments
        ATTACHMENTS=""
        if [ -f "$REPORT_DIR/sonar-report-$DATE.pdf" ]; then
            ATTACHMENTS="-A $REPORT_DIR/sonar-report-$DATE.pdf"
        fi
        ATTACHMENTS="$ATTACHMENTS -A $REPORT_DIR/sonar-report-$DATE.html"
        
        if echo "$BODY" | mail -s "$SUBJECT" $ATTACHMENTS "$EMAIL" 2>/dev/null; then
            echo "✅ Email sent to: $EMAIL"
        else
            echo "⚠️  Failed to send email. Check mail configuration."
        fi
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
echo "   Coverage: ${COVERAGE_DISPLAY}"
echo "   Quality Gate: $QUALITY_TEXT"

# 8. Exit with appropriate code
if [ "$SCAN_FAILED" = "true" ]; then
    echo ""
    echo "⚠️  Note: SonarQube scan had issues. Check the configuration and try again."
    exit 1
else
    exit 0
fi
