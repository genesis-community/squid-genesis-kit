# Deploying Squid Proxy on AWS

This guide will walk you through deploying a Squid proxy using the Genesis Kit on AWS (Amazon Web Services).

## Prerequisites

Before you begin, you'll need:

1. A BOSH director deployed on AWS
2. Genesis CLI (version 2.7.0 or higher)
3. Basic knowledge of BOSH and AWS networking
4. Proper AWS IAM permissions to deploy resources

## Step 1: Prepare Your AWS Environment

First, ensure you have proper network configuration in place:

1. **VPC Configuration**:
   - You'll need a VPC with at least two subnets:
     - A "public" subnet with an Internet Gateway attached
     - A "private" subnet for your internal workloads

2. **Security Group Configuration**:
   - Create a security group for your Squid proxy that allows:
     - Inbound traffic on port 3128 from your private networks
     - Outbound traffic on ports 80 and 443 to the internet
     - Management access from your BOSH director

   Example AWS CLI command to create a security group:
   ```bash
   aws ec2 create-security-group \
     --group-name squid-proxy-sg \
     --description "Security group for Squid proxy" \
     --vpc-id vpc-xxxxxxxx
   
   # Allow inbound traffic on port 3128 from private subnet
   aws ec2 authorize-security-group-ingress \
     --group-id sg-xxxxxxxx \
     --protocol tcp \
     --port 3128 \
     --cidr 10.0.0.0/8
   
   # Allow outbound traffic
   aws ec2 authorize-security-group-egress \
     --group-id sg-xxxxxxxx \
     --protocol tcp \
     --port 80 \
     --cidr 0.0.0.0/0
   
   aws ec2 authorize-security-group-egress \
     --group-id sg-xxxxxxxx \
     --protocol tcp \
     --port 443 \
     --cidr 0.0.0.0/0
   ```

## Step 2: Update BOSH Cloud Config

You need to ensure your BOSH cloud config has the necessary networks and VM types defined:

1. Create or update your cloud config YAML:

   ```yaml
   # cloud-config-update.yml
   networks:
   - name: squid-network
     subnets:
     - az: us-east-1a
       cloud_properties:
         subnet: subnet-xxxxxxxx # Your public subnet ID
         security_groups: [sg-xxxxxxxx] # Your Squid security group
       dns: [169.254.169.253]
       gateway: 10.0.0.1
       range: 10.0.0.0/24
       reserved: [10.0.0.1-10.0.0.10]
       static: [10.0.0.5] # Static IP for your Squid proxy
   
   vm_types:
   - name: squid-vm
     cloud_properties:
       instance_type: t3.small
       ephemeral_disk:
         size: 10240
         type: gp2
   ```

2. Update your BOSH director with the cloud config:

   ```bash
   bosh update-cloud-config cloud-config-update.yml
   ```

## Step 3: Initialize Genesis Deployment

Now, initialize a new Genesis deployment for your Squid proxy:

1. Create a new deployment repo:

   ```bash
   # Create a new directory for your deployments
   mkdir ~/deployments
   cd ~/deployments
   
   # Initialize a new repo with the Squid Genesis Kit
   genesis init --kit squid
   
   # Navigate to the created directory
   cd squid-deployments
   ```

2. Create a new environment file for AWS:

   ```bash
   # Create a new environment file
   genesis new aws-proxy
   ```

3. Edit the environment file:

   ```yaml
   # aws-proxy.yml
   ---
   kit:
     name:    squid
     version: 1.2.0
   
   genesis:
     env: aws-proxy
   
   params:
     # Network configuration
     network: squid-network
     vm_type: squid-vm
     
     # Stemcell configuration
     stemcell_os: ubuntu-jammy
     stemcell_version: latest
     
     # Availability zones
     availability_zones: [us-east-1a]
   ```

## Step 4: Deploy the Squid Proxy

Deploy your Squid proxy using Genesis:

```bash
genesis deploy aws-proxy
```

This will kick off the BOSH deployment of your Squid proxy. The deployment might take a few minutes to complete.

## Step 5: Verify the Deployment

After the deployment completes, let's verify that the Squid proxy is working correctly:

1. Check the deployment status:

   ```bash
   genesis instances aws-proxy
   ```

   You should see your Squid proxy VM running.

2. Get the proxy information:

   ```bash
   genesis info aws-proxy
   ```

   This will display the proxy's URL and how to set it up in your environment.

3. Test the proxy:

   ```bash
   # Test using the Genesis addon
   genesis do aws-proxy -- curl https://www.google.com
   
   # Or SSH into the Squid VM and test locally
   genesis ssh aws-proxy squid/0
   curl -v --proxy http://localhost:3128 https://www.google.com
   ```

## Step 6: Use the Proxy in Other Deployments

Now that your proxy is running, you can configure other deployments to use it:

1. For BOSH director:

   Update your BOSH environment file:

   ```yaml
   params:
     http_proxy: http://10.0.0.5:3128    # Use your Squid proxy's IP
     https_proxy: http://10.0.0.5:3128
     no_proxy: 127.0.0.1,localhost,169.254.169.254,*.amazonaws.com
   ```

2. For Cloud Foundry:

   Update your CF environment file similarly:

   ```yaml
   params:
     http_proxy: http://10.0.0.5:3128
     https_proxy: http://10.0.0.5:3128
     no_proxy: 127.0.0.1,localhost,169.254.169.254,*.amazonaws.com
   ```

3. Redeploy the affected systems to apply the proxy settings.

## Step 7: Monitor and Maintain

Now that your Squid proxy is deployed, set up monitoring and maintenance procedures:

1. Monitor proxy logs:

   ```bash
   genesis ssh aws-proxy squid/0 "tail -f /var/log/squid/access.log"
   ```

2. Check proxy statistics:

   ```bash
   genesis ssh aws-proxy squid/0 "squidclient -h localhost mgr:info"
   ```

3. Plan for regular updates:

   ```bash
   # When new versions of the kit are released
   cd ~/deployments/squid-deployments
   git pull
   genesis deploy aws-proxy
   ```

## Troubleshooting

If you encounter issues with your Squid deployment, refer to the [Troubleshooting Guide](troubleshooting.md) for common issues and solutions.

## Advanced Configuration

For advanced Squid configurations, such as custom ACLs or authentication, see the [ACL Examples](acl-examples.md) for detailed examples.

## Conclusion

You have now successfully deployed a Squid proxy on AWS using the Genesis Kit. This proxy can serve as an egress point for HTTP and HTTPS traffic from your restricted networks to the internet.

For more information, refer to:
- The [Genesis Squid Kit Manual](../MANUAL.md)
- [Squid Documentation](http://www.squid-cache.org/Doc/)