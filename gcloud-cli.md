# Google Cloud CLI Reference - Discovery & Querying Commands

## Project & Account Information
```bash
# Current configuration
gcloud config list
gcloud config configurations list
gcloud auth list
gcloud info

# Project details
gcloud projects describe PROJECT_ID
gcloud projects get-iam-policy PROJECT_ID
gcloud organizations list
gcloud billing accounts list
gcloud billing projects describe PROJECT_ID
```

## Service Discovery & Status
```bash
# Enabled services
gcloud services list --enabled
gcloud services list --available
gcloud service-management operations list
gcloud endpoints services list

# API quotas and usage
gcloud services quota list --service=SERVICE_NAME
gcloud logging read "protoPayload.serviceName=SERVICE_NAME" --limit=50
```

## Compute Engine Deep Dive
```bash
# Instance details
gcloud compute instances list --format="table(name,zone,machineType,status,externalIP)"
gcloud compute instances describe INSTANCE_NAME --zone=ZONE
gcloud compute instances get-serial-port-output INSTANCE_NAME --zone=ZONE

# Resource usage and metadata
gcloud compute project-info describe
gcloud compute regions list --format="table(name,status,quotas.metric:label=METRIC)"
gcloud compute zones list --format="table(name,region,status)"
gcloud compute machine-types list --zones=ZONE --format="table(name,guestCpus,memoryMb)"

# Disks and snapshots
gcloud compute disks list --format="table(name,zone,sizeGb,type,status)"
gcloud compute snapshots list --format="table(name,diskSizeGb,status,creationTimestamp)"
gcloud compute images list --no-standard-images --format="table(name,family,status,diskSizeGb)"

# Network analysis
gcloud compute networks list --format="table(name,subnet_mode,bgp_routing_mode)"
gcloud compute networks subnets list --format="table(name,region,range,network)"
gcloud compute addresses list --format="table(name,region,address,status,users)"
gcloud compute forwarding-rules list
gcloud compute target-pools list
gcloud compute backend-services list
gcloud compute health-checks list
```

## GKE Cluster Analysis
```bash
# Cluster information
gcloud container clusters list --format="table(name,location,status,currentMasterVersion,nodeVersion)"
gcloud container clusters describe CLUSTER_NAME --zone=ZONE

# Node details
gcloud container node-pools list --cluster=CLUSTER_NAME --zone=ZONE
gcloud container node-pools describe POOL_NAME --cluster=CLUSTER_NAME --zone=ZONE
gcloud container operations list

# Get cluster credentials and kubectl context
gcloud container clusters get-credentials CLUSTER_NAME --zone=ZONE
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl top nodes
kubectl describe node NODE_NAME
```

## Storage Deep Dive
```bash
# Bucket analysis
gsutil ls -L gs://BUCKET_NAME
gsutil du -s gs://BUCKET_NAME
gsutil lifecycle get gs://BUCKET_NAME
gsutil versioning get gs://BUCKET_NAME
gsutil cors get gs://BUCKET_NAME
gsutil iam get gs://BUCKET_NAME

# Object details
gsutil ls -l gs://BUCKET_NAME/**
gsutil stat gs://BUCKET_NAME/OBJECT
gsutil acl get gs://BUCKET_NAME/OBJECT

# Storage classes and locations
gsutil ls -L -b gs://BUCKET_NAME
```

## Cloud SQL Investigation
```bash
# Instance details
gcloud sql instances list --format="table(name,databaseVersion,region,tier,ipAddresses[0].ipAddress,state)"
gcloud sql instances describe INSTANCE_NAME
gcloud sql operations list --instance=INSTANCE_NAME

# Database and user info
gcloud sql databases list --instance=INSTANCE_NAME
gcloud sql users list --instance=INSTANCE_NAME
gcloud sql backups list --instance=INSTANCE_NAME

# Configuration and flags
gcloud sql instances describe INSTANCE_NAME --format="value(settings.databaseFlags)"
gcloud sql tiers list
```

## Networking Deep Analysis
```bash
# VPC and connectivity
gcloud compute networks list --format="table(name,subnet_mode,bgp_routing_mode,peerings[].network)"
gcloud compute networks peerings list --network=NETWORK_NAME
gcloud compute routers list
gcloud compute vpn-tunnels list

# Firewall analysis
gcloud compute firewall-rules list --format="table(name,direction,priority,sourceRanges.list():label=SRC_RANGES,allowed[].map().firewall_rule().list():label=ALLOW,targetTags.list():label=TARGET_TAGS)"
gcloud compute firewall-rules describe RULE_NAME

# Load balancers
gcloud compute url-maps list
gcloud compute target-http-proxies list
gcloud compute target-https-proxies list
gcloud compute ssl-certificates list
```

## IAM & Security Analysis
```bash
# Project IAM
gcloud projects get-iam-policy PROJECT_ID --format="table(bindings.role,bindings.members.flatten())"
gcloud iam roles list --project=PROJECT_ID
gcloud iam roles describe ROLE_NAME

# Service accounts
gcloud iam service-accounts list --format="table(email,displayName,disabled)"
gcloud iam service-accounts describe SA_EMAIL
gcloud iam service-accounts keys list --iam-account=SA_EMAIL

# Organization policies
gcloud resource-manager org-policies list --project=PROJECT_ID
gcloud asset search-all-resources --scope=projects/PROJECT_ID
```

## Cloud Functions & App Engine
```bash
# Functions details
gcloud functions list --format="table(name,status,trigger.eventTrigger.eventType,runtime)"
gcloud functions describe FUNCTION_NAME
gcloud functions logs read FUNCTION_NAME --limit=100

# App Engine
gcloud app describe
gcloud app versions list --format="table(id,service,version,traffic_split,last_deployed_time)"
gcloud app services list --format="table(id,versions)"
gcloud app instances list
```

## Cloud Run Services
```bash
# Service details
gcloud run services list --format="table(metadata.name,status.url,status.conditions[0].type,spec.template.spec.containers[0].image)"
gcloud run services describe SERVICE_NAME --region=REGION
gcloud run revisions list --service=SERVICE_NAME --region=REGION
```

## Artifact Registry & Container Registry
```bash
# Repositories
gcloud artifacts repositories list --format="table(name,format,location,createTime)"
gcloud artifacts repositories describe REPO_NAME --location=LOCATION

# Docker images
gcloud artifacts docker images list LOCATION-docker.pkg.dev/PROJECT_ID/REPO_NAME
gcloud container images list --repository=gcr.io/PROJECT_ID
gcloud container images list-tags gcr.io/PROJECT_ID/IMAGE_NAME
```

## Cloud Build Analysis
```bash
# Build history
gcloud builds list --format="table(id,status,source.repoSource.repoName,createTime,duration)"
gcloud builds describe BUILD_ID
gcloud builds log BUILD_ID

# Triggers
gcloud builds triggers list --format="table(name,status,github.name,github.push.branch)"
gcloud builds triggers describe TRIGGER_NAME
```

## BigQuery Investigation
```bash
# Datasets and tables
bq ls --format=prettyjson
bq show DATASET_NAME
bq show DATASET_NAME.TABLE_NAME
bq query --dry_run "SELECT * FROM dataset.table LIMIT 10"

# Jobs and usage
bq ls -j --max_results=10
bq show -j JOB_ID
```

## Monitoring & Logging Deep Dive
```bash
# Recent logs by service
gcloud logging read "resource.type=gce_instance" --limit=50 --format="table(timestamp,resource.labels.instance_id,textPayload)"
gcloud logging read "resource.type=k8s_container" --limit=50
gcloud logging read "resource.type=cloud_function" --limit=50

# Metrics and monitoring
gcloud alpha monitoring metrics list --filter="resource.type=gce_instance"
gcloud alpha monitoring policies list
gcloud alpha monitoring channels list

# Error reporting
gcloud error-reporting events list --service=SERVICE_NAME
```

## Resource Usage & Quotas
```bash
# Quota usage
gcloud compute project-info describe --format="table(quotas.metric,quotas.usage,quotas.limit)"
gcloud services quota list --service=compute.googleapis.com --consumer=projects/PROJECT_ID

# Resource inventory
gcloud asset search-all-resources --scope=projects/PROJECT_ID --asset-types=compute.googleapis.com/Instance
gcloud asset search-all-resources --scope=projects/PROJECT_ID --query="state:ACTIVE"
```

## Cost & Billing Analysis
```bash
# Billing export (if configured)
bq query "SELECT service.description, location.location, cost FROM \`PROJECT_ID.billing_dataset.gcp_billing_export_v1_BILLING_ACCOUNT_ID\` WHERE _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY) ORDER BY cost DESC LIMIT 20"

# Resource labels for cost tracking
gcloud compute instances list --format="table(name,zone,labels)"
gcloud container clusters list --format="table(name,location,resourceLabels)"
```

## Advanced Querying with Filters
```bash
# Filter examples
gcloud compute instances list --filter="status=RUNNING AND zone:us-central1"
gcloud compute disks list --filter="sizeGb>100 AND status=READY"
gcloud iam service-accounts list --filter="disabled=false"
gcloud builds list --filter="status=SUCCESS AND createTime>2023-01-01"

# Format options
--format="table(field1,field2)"
--format="value(field)"
--format="csv(field1,field2)"
--format="json"
--format="yaml"
```

## Useful Aliases & Shortcuts
```bash
# Add to ~/.bashrc or ~/.zshrc
alias gcl="gcloud compute instances list"
alias gkl="gcloud container clusters list"
alias gsl="gsutil ls"
alias gcd="gcloud config set project"
alias gci="gcloud compute instances"
alias gcs="gcloud container clusters"

# Quick project switching
gcloud config configurations create CONFIG_NAME
gcloud config configurations activate CONFIG_NAME
```

## Troubleshooting Commands
```bash
# Connectivity tests
gcloud compute instances get-serial-port-output INSTANCE_NAME --zone=ZONE
gcloud compute ssh INSTANCE_NAME --zone=ZONE --command="systemctl status"

# Service health
gcloud compute backend-services get-health BACKEND_SERVICE --global
gcloud compute target-pools get-health TARGET_POOL --region=REGION

# Debug authentication
gcloud auth print-access-token
gcloud auth print-identity-token
```

Use `--help` with any command for detailed options and `--format` flag for custom output formatting.
