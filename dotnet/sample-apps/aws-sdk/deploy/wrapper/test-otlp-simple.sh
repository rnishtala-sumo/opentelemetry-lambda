#!/bin/bash

# Simple OTLP trace test script that successfully sends traces to Sumo Logic
# This script demonstrates the correct JSON format and resource attributes structure

# Generate a random trace ID (32 hex characters)
TRACE_ID=$(openssl rand -hex 16)
# Generate a random span ID (16 hex characters)  
SPAN_ID=$(openssl rand -hex 8)

# Current timestamp in nanoseconds
TIMESTAMP_NS=$(date +%s%N)

# OTLP endpoint
ENDPOINT="https://your-endpoint.sumologic.net/receiver/v1/otlp/YOUR_TOKEN_HERE/v1/traces"

# Create JSON payload with proper resource attributes structure
JSON_PAYLOAD=$(cat <<EOF
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "manual-curl-test"
            }
          },
          {
            "key": "service.version",
            "value": {
              "stringValue": "1.0.0"
            }
          },
          {
            "key": "environment",
            "value": {
              "stringValue": "test"
            }
          }
        ]
      },
      "scopeSpans": [
        {
          "scope": {
            "name": "manual-testing",
            "version": "1.0.0"
          },
          "spans": [
            {
              "traceId": "$TRACE_ID",
              "spanId": "$SPAN_ID",
              "name": "test-operation",
              "kind": 1,
              "startTimeUnixNano": "$TIMESTAMP_NS",
              "endTimeUnixNano": "$((TIMESTAMP_NS + 1000000000))",
              "attributes": [
                {
                  "key": "operation.name",
                  "value": {
                    "stringValue": "curl-test"
                  }
                }
              ],
              "status": {
                "code": 1
              }
            }
          ]
        }
      ]
    }
  ]
}
EOF
)

echo "Sending OTLP trace to Sumo Logic..."
echo "Trace ID: $TRACE_ID"
echo "Span ID: $SPAN_ID"
echo "Timestamp: $TIMESTAMP_NS"
echo ""

# Send the request
RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$JSON_PAYLOAD" \
  "$ENDPOINT")

# Extract HTTP status code
HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
# Extract response body
RESPONSE_BODY=$(echo $RESPONSE | sed -e 's/HTTPSTATUS:.*//g')

echo "HTTP Status: $HTTP_STATUS"
if [ ! -z "$RESPONSE_BODY" ]; then
    echo "Response: $RESPONSE_BODY"
fi

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "✅ SUCCESS: Trace sent successfully!"
else
    echo "❌ FAILED: HTTP $HTTP_STATUS"
fi
