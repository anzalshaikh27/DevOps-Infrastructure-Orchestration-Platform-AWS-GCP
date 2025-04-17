const StatsD = require('hot-shots');
const { CloudWatchClient, PutMetricDataCommand } = require('@aws-sdk/client-cloudwatch');

class MetricsCollector {
  constructor() {
    // StatsD client
    this.statsd = new StatsD({
      host: 'localhost',
      port: 8125
    });

    // CloudWatch client
    this.cloudwatch = new CloudWatchClient({ 
      region: process.env.AWS_REGION || 'us-east-1' 
    });

    // Namespace for metrics
    this.namespace = 'WebAppMetrics';
  }

  // API Call Metrics
  async trackAPICall(apiName, duration, status = 'success') {
    // StatsD Metrics
    this.statsd.timing(`api.${apiName}.duration`, duration);
    this.statsd.increment(`api.${apiName}.count`);

    // CloudWatch Metrics
    try {
      await this.cloudwatch.send(new PutMetricDataCommand({
        Namespace: this.namespace,
        MetricData: [
          {
            MetricName: `${apiName}Duration`,
            Dimensions: [{ Name: 'Status', Value: status }],
            Value: duration,
            Unit: 'Milliseconds'
          },
          {
            MetricName: `${apiName}Calls`,
            Dimensions: [{ Name: 'Status', Value: status }],
            Value: 1,
            Unit: 'Count'
          }
        ]
      }));
    } catch (error) {
      console.error('Failed to send metrics to CloudWatch', error);
    }
  }

  // S3 Operation Metrics
  async trackS3Operation(operation, duration) {
    // StatsD Metrics
    this.statsd.timing(`s3.${operation}`, duration);

    // CloudWatch Metrics
    try {
      await this.cloudwatch.send(new PutMetricDataCommand({
        Namespace: 'S3Metrics',
        MetricData: [{
          MetricName: `${operation}Duration`,
          Value: duration,
          Unit: 'Milliseconds'
        }]
      }));
    } catch (error) {
      console.error('Failed to send S3 metrics', error);
    }
  }

  // Database Query Metrics
  async trackDatabaseQuery(queryName, duration) {
    // StatsD Metrics
    this.statsd.timing(`db.query.${queryName}`, duration);

    // CloudWatch Metrics
    try {
      await this.cloudwatch.send(new PutMetricDataCommand({
        Namespace: 'DatabaseMetrics',
        MetricData: [{
          MetricName: `${queryName}QueryDuration`,
          Value: duration,
          Unit: 'Milliseconds'
        }]
      }));
    } catch (error) {
      console.error('Failed to send database metrics', error);
    }
  }
}

module.exports = new MetricsCollector();