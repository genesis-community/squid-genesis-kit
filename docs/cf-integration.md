# Integrating Squid Proxy with Cloud Foundry

This guide explains how to configure a Cloud Foundry deployment to use a Squid proxy for egress traffic. This is particularly useful in environments where direct internet access is restricted, yet Cloud Foundry needs to download buildpacks, application dependencies, and other resources.

## Prerequisites

Before you begin, you should have:

1. A deployed Squid proxy using the Genesis Kit
2. Access to your Cloud Foundry Genesis Kit deployment
3. Basic understanding of Cloud Foundry architecture
4. Genesis CLI (version 2.7.0 or higher)

## Why Use a Proxy with Cloud Foundry?

Cloud Foundry requires internet access for several operations:

1. **Buildpack Downloads**: When applications are staged
2. **Service Broker Operations**: For marketplace services that need external resources
3. **Application Dependencies**: When applications need to download packages during staging
4. **Container Image Downloads**: When deploying container-based applications
5. **Route Registration**: For wildcard domain validation

Without direct internet access, these operations would fail. A Squid proxy provides controlled access to these external resources.

## Step 1: Identify Your Squid Proxy Details

First, retrieve the information about your deployed Squid proxy:

```bash
cd ~/deployments/squid-deployments
genesis info my-environment
```

This will display the proxy URL, which typically looks like:
```
http://10.10.10.5:3128
```

Note down this URL for the next steps.

## Step 2: Configure Cloud Foundry Environment

Edit your Cloud Foundry environment file to add the proxy settings:

1. Navigate to your CF deployments directory:
   ```bash
   cd ~/deployments/cf-deployments
   ```

2. Edit your environment file:
   ```bash
   # Edit the environment file for your CF deployment
   vim my-cf-env.yml
   ```

3. Add the proxy parameters:
   ```yaml
   params:
     # Existing parameters...
     
     # Proxy Configuration
     http_proxy: http://10.10.10.5:3128    # Replace with your Squid proxy IP
     https_proxy: http://10.10.10.5:3128   # Replace with your Squid proxy IP
     no_proxy: 127.0.0.1,localhost,10.0.0.0/8,internal.domain
   ```

   The `no_proxy` parameter should include:
   - Localhost addresses
   - CF internal network ranges (typically your BOSH network)
   - CF system domain (if resolved locally)
   - Any services that should bypass the proxy

## Step 3: Apply Configuration to Components

### Cloud Foundry Components

Different Cloud Foundry components need proxy configuration for different reasons:

1. **Diego Cell**: For garden container access to external resources
2. **Cloud Controller**: For buildpack downloads and service broker communications
3. **Loggregator**: For forwarding logs to external aggregators
4. **UAA**: For identity provider integrations

The Genesis kit will propagate the proxy settings to all these components when you redeploy.

### BOSH Configuration for CF

If your BOSH director is also behind a proxy, ensure it's configured correctly:

```yaml
# In your BOSH environment file
params:
  http_proxy: http://10.10.10.5:3128
  https_proxy: http://10.10.10.5:3128
  no_proxy: 127.0.0.1,localhost,10.0.0.0/8,internal.domain
```

## Step 4: Deploy Cloud Foundry with Proxy Settings

Deploy (or redeploy) your Cloud Foundry environment with the new proxy settings:

```bash
genesis deploy my-cf-env
```

This will update all CF components with the appropriate proxy settings.

## Step 5: Verify Proxy Integration

After deployment, verify that Cloud Foundry is using the proxy correctly:

1. Push a test application:
   ```bash
   cf push test-app -p /path/to/test/app
   ```

2. Check the staging logs for proxy usage:
   ```bash
   cf logs test-app --recent
   ```

   Look for messages about downloading buildpacks or dependencies through the proxy.

3. Check that the application can access external resources:
   ```bash
   cf ssh test-app -c "curl https://api.github.com"
   ```

## Step 6: Monitor Proxy Usage

To understand how Cloud Foundry is using the proxy:

1. Monitor the Squid proxy access logs:
   ```bash
   genesis do squid-env -- ssh squid/0 "tail -f /var/log/squid/access.log | grep cf"
   ```

2. Look for patterns in usage:
   - Buildpack downloads (URLs containing "buildpacks")
   - Service broker calls
   - Application dependency downloads

## Troubleshooting Common Issues

### Staging Failures

If application staging fails with download errors:

1. Verify the Squid proxy is working:
   ```bash
   genesis do squid-env -- curl https://github.com
   ```

2. Check if the URL is being blocked by ACLs:
   - Review your Squid ACL configuration
   - Ensure the necessary domains are allowed
   - Check Squid logs for denied requests

3. Verify proxy settings are properly applied:
   ```bash
   bosh -d cf-my-cf-env ssh diego-cell/0 -c "env | grep -i proxy"
   ```

### Service Broker Issues

If service broker operations fail:

1. Check if the broker needs special domains in the ACL:
   - Determine what domains the broker needs to access
   - Update the Squid ACL if necessary

2. Verify the broker is configured to use the proxy:
   ```bash
   bosh -d cf-my-cf-env ssh api/0 -c "grep -r proxy /var/vcap/jobs/"
   ```

## Advanced Configuration

### Custom No-Proxy Rules

For advanced setups, you might need to customize the `no_proxy` list:

```yaml
params:
  no_proxy: >-
    127.0.0.1,
    localhost,
    10.0.0.0/8,
    *.internal,
    *.cf.internal,
    *.service.cf.internal,
    bosh-dns.service.cf.internal
```

### Service-Specific Proxy Configuration

Some CF services might need special proxy handling:

```yaml
params:
  # Basic proxy settings
  http_proxy: http://10.10.10.5:3128
  https_proxy: http://10.10.10.5:3128
  no_proxy: 127.0.0.1,localhost,10.0.0.0/8
  
  # Component-specific override (example)
  routing_proxy:
    http_proxy: http://special-proxy.internal:8080
    https_proxy: http://special-proxy.internal:8080
```

## Conclusion

Your Cloud Foundry deployment should now successfully use the Squid proxy for all egress traffic, allowing it to function in a restricted network environment. This setup provides:

1. Controlled access to external resources
2. Enhanced security through traffic filtering
3. Potential bandwidth savings through caching
4. Auditable access logs for compliance

For more advanced Squid configurations, refer to the [ACL Examples](acl-examples.md) guide.

If you encounter issues, consult the [Troubleshooting Guide](troubleshooting.md) for more details.