# Troubleshooting Squid Proxy Deployments

This guide covers common issues that you might encounter when deploying and using the Squid Genesis Kit.

## Deployment Issues

### Failed Cloud Check

**Symptoms:** Deployment fails with cloud check errors.

**Possible Causes:**
- The cloud config doesn't include the required networks or VM types.
- The specified availability zone doesn't exist in your BOSH director.

**Solutions:**
1. Verify your cloud config includes the necessary components:
   ```
   bosh cloud-config
   ```
2. Update your environment file to use existing networks and VM types.
3. If necessary, update your cloud config:
   ```
   bosh update-cloud-config cloud-config.yml
   ```

### Failed VM Creation

**Symptoms:** BOSH cannot create the VM for the Squid proxy.

**Possible Causes:**
- Resource constraints in the IaaS
- Networking issues
- Stemcell issues

**Solutions:**
1. Check BOSH task logs for specific error messages:
   ```
   bosh task <task-id> --debug
   ```
2. Verify the stemcell exists on your BOSH director:
   ```
   bosh stemcells
   ```
3. If using a specific stemcell version, try using `latest` instead.

## Connectivity Issues

### Proxy Not Accessible

**Symptoms:** Cannot connect to the proxy from client machines.

**Possible Causes:**
- Network routing issues
- Firewall blocking access
- Squid service not running

**Solutions:**
1. Verify the Squid instance is running:
   ```
   genesis <env> instances
   ```

2. Check that the proxy is listening on the expected port:
   ```
   genesis <env> ssh squid/0 "netstat -lntp | grep squid"
   ```

3. Test connectivity from the proxy VM itself:
   ```
   genesis <env> ssh squid/0 "curl -v --proxy localhost:3128 https://www.google.com"
   ```

4. Check firewall rules between client and proxy.

### Proxy Returns Access Denied

**Symptoms:** When trying to use the proxy, you get "Access Denied" errors.

**Possible Causes:**
- ACL rules are blocking your client's IP address
- Attempting to access a port that is not allowed
- Trying to use CONNECT method for non-SSL ports

**Solutions:**
1. Verify your client's IP is within the allowed ranges in the ACL.
2. Check the Squid logs for denied requests:
   ```
   genesis <env> ssh squid/0 "tail -f /var/log/squid/access.log"
   ```
3. Modify the ACL to allow your client's IP range:
   ```yaml
   params:
     acl: |
       acl localnet src 10.0.0.0/8
       acl localnet src 172.16.0.0/12
       acl localnet src 192.168.0.0/16
       acl localnet src YOUR_IP_RANGE/MASK  # Add your network range
       ...
   ```

### Cannot Connect to HTTPS Sites

**Symptoms:** HTTP sites work but HTTPS sites fail.

**Possible Causes:**
- SSL/TLS tunneling (CONNECT method) is being blocked
- Proxy not configured for SSL sites

**Solutions:**
1. Verify your ACL allows the CONNECT method on port 443:
   ```
   acl SSL_ports port 443
   http_access deny CONNECT !SSL_ports
   ```
2. Test with an explicit HTTPS URL:
   ```
   curl -v --proxy http://proxy-ip:3128 https://www.google.com
   ```

## Integration Issues

### BOSH Director Not Using Proxy

**Symptoms:** BOSH Director can't download stemcells or releases despite proxy configuration.

**Possible Causes:**
- Proxy parameters not correctly set
- `no_proxy` settings blocking needed traffic
- Network routing issues between Director and Proxy

**Solutions:**
1. Verify proxy settings in the BOSH environment:
   ```yaml
   params:
     http_proxy:  http://proxy-ip:3128
     https_proxy: http://proxy-ip:3128
     no_proxy:    127.0.0.1,localhost,director-ip
   ```
2. Check that the BOSH Director can reach the proxy:
   ```
   bosh ssh -d bosh bosh/0 "curl -v telnet://proxy-ip:3128"
   ```
3. Test downloading from the BOSH Director through the proxy:
   ```
   bosh ssh -d bosh bosh/0 "http_proxy=http://proxy-ip:3128 curl -v https://bosh.io"
   ```

### Cloud Foundry Not Using Proxy

**Symptoms:** Cloud Foundry can't download buildpacks despite proxy configuration.

**Possible Causes:**
- Proxy parameters not correctly set on CF deployment
- Network issues between CF components and Proxy

**Solutions:**
1. Verify proxy settings in the CF environment:
   ```yaml
   params:
     http_proxy:  http://proxy-ip:3128
     https_proxy: http://proxy-ip:3128
     no_proxy:    127.0.0.1,localhost,internal-ips
   ```
2. Check connectivity from CF components to the proxy.
3. Verify that traffic to buildpack sources is not in the `no_proxy` list.

## Performance Issues

### Slow Proxy Response

**Symptoms:** Connections through the proxy are unusually slow.

**Possible Causes:**
- VM under-provisioned for the load
- Network bandwidth constraints
- Cache not properly configured

**Solutions:**
1. Check CPU and memory usage on the Squid VM:
   ```
   genesis <env> ssh squid/0 "top -b -n 1"
   ```
2. Monitor network utilization:
   ```
   genesis <env> ssh squid/0 "nload" # may need to be installed
   ```
3. Consider increasing the VM size by changing the `vm_type` parameter.
4. For high-volume deployments, consider implementing a custom caching configuration.

### High CPU Usage

**Symptoms:** The Squid proxy VM shows consistently high CPU usage.

**Possible Causes:**
- Too many concurrent connections for the VM size
- SSL/TLS overhead
- Inefficient ACL rules

**Solutions:**
1. Increase VM resources by specifying a larger `vm_type`.
2. Optimize ACL rules by removing unnecessary complexity.
3. Consider adding cache directives to improve efficiency.

## Advanced Diagnostics

### Analyzing Squid Logs

The main Squid logs are:

- **Access Log**: `/var/log/squid/access.log` - Records all request information
- **Cache Log**: `/var/log/squid/cache.log` - General squid messages and errors
- **Store Log**: `/var/log/squid/store.log` - Information about cached objects

To view these logs:

```
genesis <env> ssh squid/0 "tail -f /var/log/squid/access.log"
```

### Testing Proxy Functionality

To test if the proxy is working correctly:

```
# Test HTTP
curl -v --proxy http://proxy-ip:3128 http://example.com

# Test HTTPS
curl -v --proxy http://proxy-ip:3128 https://example.com
```

### Restarting the Squid Service

If you need to restart the Squid service:

```
genesis <env> ssh squid/0 "sudo monit restart squid"
```

This will use BOSH's monit service to safely restart the Squid process.

## Getting Help

If you still face issues after trying these troubleshooting steps:

1. Check if there are known issues in the [GitHub repository](https://github.com/genesis-community/squid-genesis-kit).
2. Review the [Genesis community documentation](https://github.com/genesis-community/genesis).
3. For issues specific to Squid itself, check the [Squid documentation](http://www.squid-cache.org/Doc/).