# 1	Overview
This solution provides the ability to monitor multiple HTTPS enabled endpoints and send alerts in case the presented SSL certificates come within a certain threshold of expiring. The solution uses the following Azure Services:

* [Azure Automation](https://docs.microsoft.com/en-us/azure/automation/overview)
* [Azure Monitor Logs](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-platform-logs)
* [Azure Alerts](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)

##	Problem Statement
SSL certificates have a predetermined validity period (usually 2 years or less) at the end of which the certificate is no longer considered usable. The impact of using an expired certificate varies depending on application behavior - web browsers may present a warning message to the end user allowing opting in/out, while other client applications will usually reject the certificate causing the SSL handshake to fail and therefore breaking the client/server flow.

The certificate renewal process itself, as well as any necessary endpoint re-configurations, are usually not automated tasks so it is critical that these are triggered with enough time ahead of the certificate expiration date.

Although CAs and other services responsible for emiting SSL certificates will send expiration notifications at predefined intervals (starting at 90 days out) certificate management can easily become a challenge for most organizations. It is often the case that site admins and other operations personnel do not have adequate visibility over the validity status of all the SSL certificates used accross their application ecosystem.

## Solution Design

![](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/images/monitor-ssl-certificate-expiration-architecture-diagram.drawio.png)

This solution consists of: 

* An Azure Automation Account containing:
  * The following Variables:
    * List of HTTPS endpoint URLs to monitor
    * Log Analytics Workspace ID
    * Log Analytics Primary Key
  * A Runbook consisting of a PowerShell script which executes the following steps for each URL:
    * executes an HTTP GET request on the URL in order to retrieve the SSL certificate
    * parses the certificate and calculates the number of days remaining until certificate expiration
    * sends an entry to Log Analytics Workpace containing the URL and the number of days calculated in previous step
  * A Schedule which specifies the Runbook's recurring (daily) execution

* A Log Analytics Workspace which will be used to store the monitored SSL certificate data

* One or more Azure Alert rules based on Log Analytics queries which fire alerts based on the results 

