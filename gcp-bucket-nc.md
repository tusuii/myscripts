https://docs.cloud.google.com/storage/docs/hosting-static-website#command-line
https://docs.cloud.google.com/storage/docs/access-control/iam-roles#standard-roles


gcloud storage cp index.html gs://my-web-page

gcloud storage buckets update gs://my-web-page --web-main-page-suffix=index.html --web-error-page=404.html





------------------------------------------code
POST https://compute.googleapis.com/compute/v1/projects/vibrant-epsilon-475606-f6/global/backendBuckets
{
  "bucketName": "my-web-page",
  "cdnPolicy": {
    "cacheMode": "CACHE_ALL_STATIC",
    "clientTtl": 3600,
    "defaultTtl": 3600,
    "maxTtl": 86400,
    "negativeCaching": false,
    "serveWhileStale": 0
  },
  "compressionMode": "DISABLED",
  "description": "webpage",
  "enableCdn": true,
  "name": "my-web-page"
}

POST https://compute.googleapis.com/compute/v1/projects/vibrant-epsilon-475606-f6/global/urlMaps
{
  "defaultService": "projects/vibrant-epsilon-475606-f6/global/backendBuckets/my-web-page",
  "name": "my-web-page"
}

POST https://compute.googleapis.com/compute/v1/projects/vibrant-epsilon-475606-f6/global/targetHttpProxies
{
  "name": "my-web-page-target-proxy",
  "urlMap": "projects/vibrant-epsilon-475606-f6/global/urlMaps/my-web-page"
}

POST https://compute.googleapis.com/compute/beta/projects/vibrant-epsilon-475606-f6/global/forwardingRules
{
  "IPAddress": "projects/vibrant-epsilon-475606-f6/global/addresses/ip-addr",
  "IPProtocol": "TCP",
  "description": "my-web-page",
  "loadBalancingScheme": "EXTERNAL_MANAGED",
  "name": "my-web-page",
  "networkTier": "PREMIUM",
  "portRange": "80",
  "target": "projects/vibrant-epsilon-475606-f6/global/targetHttpProxies/my-web-page-target-proxy"
}

POST https://compute.googleapis.com/compute/v1/projects/vibrant-epsilon-475606-f6/global/targetHttpProxies
{
  "name": "my-web-page-target-proxy-2",
  "urlMap": "projects/vibrant-epsilon-475606-f6/global/urlMaps/my-web-page"
}

POST https://compute.googleapis.com/compute/beta/projects/vibrant-epsilon-475606-f6/global/forwardingRules
{
  "IPProtocol": "TCP",
  "description": "ip-addr",
  "ipVersion": "IPV4",
  "loadBalancingScheme": "EXTERNAL_MANAGED",
  "name": "ip-addr",
  "networkTier": "PREMIUM",
  "portRange": "80",
  "target": "projects/vibrant-epsilon-475606-f6/global/targetHttpProxies/my-web-page-target-proxy-2"
}
