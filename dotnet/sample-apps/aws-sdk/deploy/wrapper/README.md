# .NET Lambda with OpenTelemetry Collector Layer

This deployment demonstrates how to send OpenTelemetry traces from a .NET Lambda function to Sumo Logic using a **custom collector layer** without modifying the original Function.cs code.

## 🏗️ Architecture

```text
┌─────────────────────┐    OTLP     ┌──────────────────────┐    HTTP     ┌─────────────┐
│   .NET Lambda       │ ────────►   │ Collector Layer      │ ────────►   │ Sumo Logic  │
│   Function          │  (default)  │ (Lambda Extension)   │ (protobuf)  │ OTLP Endpoint│
│   (Function.cs)     │             │ localhost:4318       │             │             │
└─────────────────────┘             └──────────────────────┘             └─────────────┘
```

## ✨ Key Features

- **Zero code changes** to the original Function.cs
- **Custom OpenTelemetry collector layer** handles trace forwarding
- **Automatic AWS SDK instrumentation** for S3 operations
- **Direct OTLP export** to Sumo Logic with proper authentication
- **Production-ready configuration** with minimal complexity

## 📁 Project Structure

```text
deploy/wrapper/
├── README.md                    # This file
├── main.tf                      # Terraform configuration
├── terraform.tfvars            # Configuration variables
├── collector-config.yaml       # Collector configuration
├── SampleApps.zip              # Lambda deployment package
└── test-otlp-simple.sh         # Test script
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed
- .NET 6 SDK
- Sumo Logic OTLP endpoint URL

### 1. Configure Variables

Update `terraform.tfvars` with your Sumo Logic endpoint:

```hcl
# Custom OpenTelemetry Collector Layer
collector_layer_arn = "arn:aws:lambda:us-east-1:586421305253:layer:otel-collector:5"

# Sumo Logic Configuration
sumo_logic_otlp_endpoint = "https://your-endpoint.sumologic.net/receiver/v1/otlp/YOUR_TOKEN/v1/traces"

# Basic Configuration
aws_region   = "us-east-1"
service_name = "otel-dotnet-sample"
environment  = "dev"
```

### 2. Build Lambda Function

```bash
cd ../../../wrapper/SampleApps
./build.sh
```

### 3. Copy Package

```bash
cp build/function.zip ../../deploy/wrapper/SampleApps.zip
```

### 4. Deploy

```bash
cd ../../deploy/wrapper
terraform init
terraform apply
```

### 5. Test

```bash
# Test Lambda function
curl $(terraform output -raw api-gateway-url)

# Test OTLP connectivity
./test-otlp-simple.sh
```

## 🔧 Configuration Details

### Lambda Function (Function.cs)

The original Function.cs uses basic OpenTelemetry configuration:

```csharp
tracerProvider = Sdk.CreateTracerProviderBuilder()
    .AddAWSInstrumentation()           // AWS SDK auto-instrumentation
    .AddOtlpExporter()                 // Default OTLP exporter
    .AddAWSLambdaConfigurations()      // Lambda-specific configs
    .Build();
```

**Key aspects:**

- ✅ No custom endpoint configuration needed
- ✅ Uses default OTLP exporter settings
- ✅ Automatic service name from Lambda function name
- ✅ AWS SDK operations automatically traced

### Collector Layer Configuration

The collector layer (`collector-config.yaml`) handles:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: localhost:4317
      http:
        endpoint: localhost:4318

exporters:
  otlphttp:
    endpoint: ${SUMO_LOGIC_OTLP_ENDPOINT}
    headers:
      Content-Type: application/x-protobuf
    encoding: proto

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [debug, otlphttp]
```

**Key features:**

- ✅ Receives traces on `localhost:4318` (HTTP)
- ✅ Exports to Sumo Logic with protobuf encoding
- ✅ Debug logging for troubleshooting
- ✅ Proper Content-Type headers

## 📊 Monitoring

### Lambda Logs

Monitor OpenTelemetry collector activity:

```bash
aws logs get-log-events \
  --log-group-name "/aws/lambda/hello-dotnet-awssdk-wrapper" \
  --log-stream-name "LATEST_STREAM_NAME" \
  --region us-east-1
```

Look for logs containing:

- `"Launching OpenTelemetry Lambda extension"`
- `"Traces","resource spans":1,"spans":1`
- Trace IDs and span details

### Trace Structure

Each Lambda invocation generates traces with:

```text
Trace ID: 85e7979fd6ce571c6e54fb83b3fd97db
├── S3.ListBuckets (span)
    ├── aws.service: S3
    ├── aws.operation: ListBuckets
    ├── aws.region: us-east-1
    ├── aws.requestId: 3K4D7W1AVN1ERYVS
    └── http.status_code: 200
```

### Sumo Logic Integration

Traces appear in Sumo Logic with:

- **Service name**: `hello-dotnet-awssdk-wrapper`
- **Cloud provider**: `aws`
- **Resource attributes**: Lambda function metadata
- **Span attributes**: AWS SDK operation details

## 🛠️ Troubleshooting

### Common Issues

1. **No traces in Sumo Logic**
   - Verify collector layer ARN is correct
   - Check Sumo Logic endpoint URL format
   - Validate authentication token

2. **Lambda function errors**
   - Check CloudWatch logs for initialization errors
   - Verify collector layer compatibility (x86_64)
   - Ensure proper IAM permissions

3. **Collector issues**
   - Look for "Launching OpenTelemetry Lambda extension" in logs
   - Check for HTTP 400/401 errors in collector output
   - Verify protobuf encoding configuration

### Debug Commands

```bash
# Check function deployment
terraform show

# Get recent logs
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/hello-dotnet-awssdk-wrapper" \
  --order-by LastEventTime --descending

# Test OTLP endpoint
./test-otlp-simple.sh

# Manual function test
curl https://YOUR_API_GATEWAY_URL/default
```

## 🔄 Deployment Workflow

### Standard Deployment

1. **Modify Function.cs** (if needed)
2. **Build**: `./build.sh` in SampleApps directory
3. **Copy**: Package to deployment directory
4. **Deploy**: `terraform apply`
5. **Test**: Verify function and traces

### Layer Updates

To update the collector layer:

1. **Build new layer**: In `collector/` directory
2. **Update ARN**: In `terraform.tfvars`
3. **Deploy**: `terraform apply`

## 📋 Environment Variables

The deployment automatically sets:

| Variable | Value | Purpose |
|----------|-------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `localhost:4318` | Collector endpoint |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` | Export protocol |
| `AWS_LAMBDA_EXEC_WRAPPER` | `/opt/otel-instrument` | Lambda wrapper |

## 📚 References

- [OpenTelemetry Lambda Layer Documentation](https://github.com/open-telemetry/opentelemetry-lambda)
- [Sumo Logic OTLP Integration](https://help.sumologic.com/docs/apm/traces/get-started-transaction-tracing/opentelemetry-instrumentation/)
- [AWS Lambda Terraform Module](https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws)

## 🏷️ Version Information

- **.NET Runtime**: dotnet6
- **OpenTelemetry .NET**: 1.1.0.52
- **Collector Version**: v0.132.0
- **Lambda Architecture**: x86_64
