# Network Connectivity Center (NCC) Simple Topology

This Terraform configuration deploys a simple Network Connectivity Center hub-and-spoke topology in Google Cloud Platform.

## Architecture Overview

The deployment creates:
- **1 NCC Hub**: Central connectivity hub
- **2 VPC Networks**: Isolated networks acting as spokes
- **2 Subnets**: One in each VPC (10.1.0.0/24 and 10.2.0.0/24)
- **2 Test VMs**: One in each spoke for connectivity testing
- **Firewall Rules**: Allow internal communication between spokes

## Prerequisites

- Google Cloud Project with billing enabled
- Terraform installed (>= 1.0)
- `gcloud` CLI configured with appropriate permissions
- Required IAM permissions:
  - Compute Admin
  - Network Admin
  - Service Usage Admin

## Quick Start

### 1. Clone and Setup

```bash
# Save the terraform code to main.tf
# Set your project ID
export TF_VAR_project_id="your-gcp-project-id"

# Optional: customize region and zone
export TF_VAR_region="us-central1"
export TF_VAR_zone="us-central1-a"
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Apply the configuration
terraform apply
```

### 3. Verify Deployment

```bash
# Check the outputs
terraform output

# List NCC resources
gcloud network-connectivity hubs list
gcloud network-connectivity spokes list
```

## Testing Connectivity

### 1. Get VM Information

```bash
# Get VM internal IPs
terraform output spoke_1_vm_internal_ip
terraform output spoke_2_vm_internal_ip

# Or use gcloud
gcloud compute instances list --filter="name~ncc-spoke"
```

### 2. Test Inter-Spoke Communication

#### Option A: Using Cloud Shell

```bash
# SSH to VM in Spoke 1
gcloud compute ssh ncc-spoke-1-vm --zone=us-central1-a

# From inside the VM, ping the other spoke
ping <spoke-2-vm-internal-ip>
```

#### Option B: Using gcloud compute ssh with commands

```bash
# Test connectivity from Spoke 1 to Spoke 2
gcloud compute ssh ncc-spoke-1-vm --zone=us-central1-a --command="ping -c 4 <spoke-2-vm-internal-ip>"

# Test connectivity from Spoke 2 to Spoke 1
gcloud compute ssh ncc-spoke-2-vm --zone=us-central1-a --command="ping -c 4 <spoke-1-vm-internal-ip>"
```

### 3. Test HTTP Communication

```bash
# Test HTTP service (Apache installed via startup script)
gcloud compute ssh ncc-spoke-1-vm --zone=us-central1-a --command="curl -I http://<spoke-2-vm-internal-ip>"
```

## Verification Commands

### Check NCC Hub Status

```bash
# List hubs
gcloud network-connectivity hubs list

# Describe the hub
gcloud network-connectivity hubs describe ncc-hub --global
```

### Check Spoke Status

```bash
# List spokes
gcloud network-connectivity spokes list

# Describe a spoke
gcloud network-connectivity spokes describe ncc-spoke-1 --global
```

### Check Route Exchange

```bash
# Check routes in VPC 1
gcloud compute routes list --filter="network:ncc-spoke-vpc-1"

# Check routes in VPC 2
gcloud compute routes list --filter="network:ncc-spoke-vpc-2"
```

## Expected Results

✅ **Successful connectivity test shows:**
- Ping between VMs in different spokes works
- HTTP requests between spokes succeed
- Routes are automatically exchanged through the NCC hub
- No additional routing configuration needed

## Troubleshooting

### Common Issues

1. **API not enabled**
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable networkconnectivity.googleapis.com
   ```

2. **Insufficient permissions**
   ```bash
   # Check current permissions
   gcloud auth list
   gcloud projects get-iam-policy $PROJECT_ID
   ```

3. **Firewall blocking traffic**
   ```bash
   # Check firewall rules
   gcloud compute firewall-rules list --filter="network~ncc-spoke"
   ```

### Debug Commands

```bash
# Check VM status
gcloud compute instances describe ncc-spoke-1-vm --zone=us-central1-a

# Check network connectivity
gcloud compute networks describe ncc-spoke-vpc-1
gcloud compute networks describe ncc-spoke-vpc-2

# Check NCC hub routing
gcloud network-connectivity hubs describe ncc-hub --global --format="yaml"
```

## Understanding the Results

### What NCC Provides

1. **Transitive Connectivity**: VMs in different spokes can communicate directly
2. **Automatic Route Exchange**: No manual route configuration needed
3. **Centralized Management**: Single hub manages all spoke connectivity
4. **Scalability**: Easy to add more spokes to the topology

### Network Flow

```
VM in Spoke 1 → VPC 1 → NCC Hub → VPC 2 → VM in Spoke 2
```

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Confirm cleanup
gcloud network-connectivity hubs list
gcloud network-connectivity spokes list
```

## Next Steps

- **Add more spokes**: Create additional VPCs and connect them to the hub
- **Implement Cloud NAT**: For outbound internet access
- **Add Cloud VPN**: Connect on-premises networks as spokes
- **Monitor traffic**: Use VPC Flow Logs and Cloud Monitoring
- **Implement security**: Add more granular firewall rules

## Cost Considerations

- **NCC Hub**: ~$0.04 per hour
- **VPC Spokes**: ~$0.04 per spoke per hour
- **Compute instances**: e2-micro instances (free tier eligible)
- **Data transfer**: Standard GCP networking charges apply

## Security Notes

- VMs are created without external IPs for security
- Firewall rules allow only necessary internal traffic
- Service accounts use minimal required scopes
- Consider implementing more restrictive firewall rules for production use