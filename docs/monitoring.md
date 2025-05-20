# Monitoring Your Squid Proxy Deployment

This guide covers approaches for monitoring your Squid proxy deployment, including built-in tools, third-party integrations, and best practices.

## Built-in Monitoring Tools

### BOSH Health Monitoring

BOSH provides basic health monitoring for all deployments:

1. **VM Status**: Check basic VM health
   ```bash
   genesis instances my-env
   ```

2. **Process Status**: Verify the Squid process is running
   ```bash
   genesis ssh my-env squid/0 "sudo monit summary"
   ```

3. **VM Vitals**: Check CPU, memory, and disk usage
   ```bash
   bosh -d squid-my-env vms --vitals
   ```

### Squid's Built-in Monitoring

Squid provides several built-in tools for monitoring its status:

1. **Cache Manager Interface**: Access Squid's cache manager
   ```bash
   genesis ssh my-env squid/0 "squidclient -h localhost mgr:info"
   ```

2. **Squid Stats**: Get detailed statistics
   ```bash
   genesis ssh my-env squid/0 "squidclient -h localhost mgr:stats"
   ```

3. **Active Connections**: View current connections
   ```bash
   genesis ssh my-env squid/0 "squidclient -h localhost mgr:active_requests"
   ```

4. **Cache Stats**: Check caching efficiency
   ```bash
   genesis ssh my-env squid/0 "squidclient -h localhost mgr:storedir"
   ```

### Log Analysis

Squid generates several logs that are valuable for monitoring:

1. **Access Log**: Records all client requests
   ```bash
   genesis ssh my-env squid/0 "tail -f /var/log/squid/access.log"
   ```

2. **Cache Log**: General Squid messages and errors
   ```bash
   genesis ssh my-env squid/0 "tail -f /var/log/squid/cache.log"
   ```

3. **Store Log**: Information about objects stored in the cache
   ```bash
   genesis ssh my-env squid/0 "tail -f /var/log/squid/store.log"
   ```

## Integrating with External Monitoring Systems

### Setting Up Prometheus Monitoring

To monitor Squid with Prometheus:

1. **Install the Squid Exporter**: Deploy [squid_exporter](https://github.com/boynux/squid-exporter) next to your Squid proxy

   Create a custom job to install the exporter:
   
   ```yaml
   instance_groups:
   - name: squid
     jobs:
     - name: squid_exporter
       release: prometheus
       properties:
         squid_exporter:
           squid:
             address: localhost:3128
   ```

2. **Configure Prometheus Scraping**: Add a scrape configuration for the Squid exporter
   
   ```yaml
   scrape_configs:
   - job_name: 'squid'
     static_configs:
     - targets: ['squid-ip:9301']
   ```

3. **Create Grafana Dashboards**: Import or create dashboards for visualizing Squid metrics

   Key metrics to dashboard:
   - HTTP request rates
   - Cache hit/miss ratio
   - Response time
   - Error rates
   - Memory and CPU usage

### Integrating with ELK Stack

To send Squid logs to an ELK (Elasticsearch, Logstash, Kibana) stack:

1. **Deploy Filebeat**: Add Filebeat to the Squid VM to ship logs

   ```yaml
   instance_groups:
   - name: squid
     jobs:
     - name: filebeat
       release: elastic
       properties:
         filebeat:
           inputs:
           - type: log
             paths:
             - /var/log/squid/access.log
             fields:
               type: squid-access
           - type: log
             paths:
             - /var/log/squid/cache.log
             fields:
               type: squid-cache
           output:
             elasticsearch:
               hosts: ["elasticsearch-host:9200"]
   ```

2. **Create Logstash Filters**: Configure Logstash to parse Squid logs
   
   ```
   filter {
     if [fields][type] == "squid-access" {
       grok {
         match => { "message" => "%{NUMBER:timestamp}\s+%{NUMBER:response_time} %{IPORHOST:client_address} %{WORD:cache_result}/%{POSINT:status_code} %{NUMBER:bytes} %{WORD:request_method} %{NOTSPACE:url} %{NOTSPACE:user} %{WORD:hierarchy_code}/%{IPORHOST:server} %{NOTSPACE:content_type}" }
       }
       date {
         match => [ "timestamp", "UNIX" ]
       }
     }
   }
   ```

3. **Create Kibana Visualizations**: Build dashboards for Squid log analysis
   
   Useful visualizations include:
   - Request volume over time
   - Top requested URLs
   - Status code distribution
   - Cache hit/miss ratio

### BOSH Metrics with InfluxDB and Telegraf

To capture system-level metrics from your Squid deployment:

1. **Deploy Telegraf**: Add Telegraf to collect system metrics
   
   ```yaml
   instance_groups:
   - name: squid
     jobs:
     - name: telegraf-agent
       release: telegraf
       properties:
         telegraf:
           outputs:
             influxdb:
               urls: ["http://influxdb-host:8086"]
               database: "bosh_metrics"
           inputs:
             cpu:
               percpu: true
               totalcpu: true
             disk:
               mount_points: ["/", "/var/vcap/data"]
             mem:
             net:
             netstat:
             procstat:
               pattern: "squid"
   ```

2. **Configure Grafana**: Create dashboards for system-level metrics

## Performance Monitoring

Key performance indicators to monitor:

1. **Response Time**: Average time to serve requests
   - Normal: < 100ms
   - Warning: 100-500ms
   - Critical: > 500ms

2. **Cache Hit Ratio**: Percentage of requests served from cache
   - Good: > 30%
   - Target: > 50% for static content

3. **Connection Statistics**:
   - Number of active connections
   - Number of waiting connections
   - Connection failures

4. **Bandwidth Usage**:
   - Inbound traffic (client to proxy)
   - Outbound traffic (proxy to internet)

## Setting Up Alerting

### Critical Alerts

Configure alerts for these critical conditions:

1. **Squid Process Down**: Trigger immediate alert
   ```
   alert: SquidDown
   expr: up{job="squid"} == 0
   for: 1m
   ```

2. **High Error Rate**: Alert on elevated HTTP errors
   ```
   alert: SquidHighErrorRate
   expr: rate(squid_client_http_errors_total[5m]) / rate(squid_client_http_requests_total[5m]) > 0.1
   for: 5m
   ```

3. **Memory Exhaustion**: Alert when memory usage is too high
   ```
   alert: SquidHighMemoryUsage
   expr: process_resident_memory_bytes{job="squid"} / on(instance) node_memory_MemTotal_bytes * 100 > 85
   for: 10m
   ```

### Warning Alerts

Configure warnings for these conditions:

1. **Cache Hit Ratio Dropping**:
   ```
   alert: SquidLowCacheHitRatio
   expr: squid_cache_hit_ratio < 20
   for: 30m
   ```

2. **Elevated Response Time**:
   ```
   alert: SquidSlowResponses
   expr: rate(squid_http_requests_total{status_code=~"2.."}[5m]) > 0 and squid_http_response_time_average > 0.3
   for: 10m
   ```

## Best Practices for Monitoring

1. **Baseline Your Metrics**: Establish normal performance patterns
   - Document typical request rates
   - Understand daily/weekly usage patterns
   - Know your cache hit ratio baseline

2. **Retention Policies**:
   - High-resolution metrics (10s): 24 hours
   - Medium-resolution metrics (1m): 7 days
   - Low-resolution metrics (5m): 30 days
   - Aggregated metrics (1h): 1 year

3. **Dashboard Organization**:
   - Overview dashboard: general health
   - Performance dashboard: detailed metrics
   - Troubleshooting dashboard: debug information

4. **Alert Escalation**:
   - Tier 1: Non-critical alerts (email/chat)
   - Tier 2: Performance degradation (paging)
   - Tier 3: Service outage (paging with escalation)

## Automating Regular Checks

Create a script for regular health checks:

```bash
#!/bin/bash
# squid_check.sh - Basic Squid health check

# Get the Squid proxy address from genesis info
PROXY_URL=$(genesis info my-env | grep http_proxy | awk '{print $2}')

echo "Checking Squid proxy at $PROXY_URL..."

# Test proxy connectivity
curl -s -o /dev/null -w "Connection test: %{http_code}\n" --proxy $PROXY_URL https://www.google.com

# Get cache hit statistics
genesis ssh my-env squid/0 "echo 'cache.hit/60' | squidclient -h localhost mgr:counters" | grep -E '^client_http|cache_hit'

# Check system load
genesis ssh my-env squid/0 "uptime"

# Check disk usage
genesis ssh my-env squid/0 "df -h /var/spool/squid"

# Check squid service status
genesis ssh my-env squid/0 "sudo monit summary | grep squid"
```

Run this script regularly from your operations systems or as a cron job.

## Conclusion

A comprehensive monitoring strategy for your Squid proxy should include:

1. Regular health checks using BOSH and Squid's built-in tools
2. Integration with external monitoring systems for metrics collection
3. Log aggregation and analysis
4. Alerting for critical conditions
5. Performance tracking and trend analysis

By implementing these monitoring practices, you'll ensure high availability and performance of your Squid proxy deployment.

## Further Reading

- [Squid Wiki: Monitoring](http://wiki.squid-cache.org/SquidFaq/SquidLogs)
- [Prometheus Exporters](https://prometheus.io/docs/instrumenting/exporters/)
- [ELK Stack Documentation](https://www.elastic.co/guide/index.html)