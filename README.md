# 1	Overview
This solution provides the ability to monitor multiple HTTPS enabled endpoints and send alerts in case the presented SSL certificates come within a certain threshold of expiring.

##	Problem Statement
SSL certificates have a predetermined validity period (usually 2 years or less) at the end of which the certificate is no longer considered usable. The impact of using an expired certificate varies depending on application behavior - web browsers may present a warning message to the end user allowing opting in/out, while other client applications will usually reject the certificate causing the SSL handshake to fail and therefore breaking the client/server flow.

The certificate renewal process itself, as well as any necessary endpoint re-configurations, are usually not automated tasks so it is critical that these are triggered with enough time ahead of the certificate expiration date.

Although CAs and other services responsible for emiting SSL certificates will send expiration notifications at predefined intervals (starting at 90 days out) certificate management can easily become a challenge for most organizations. It is often the case that site admins and other operations personnel do not have adequate visibility over the validity status of all the SSL certificates used accross their application ecosystem.

## Solution Design
This solution uses the following Azure Services:

* [Azure Automation](https://docs.microsoft.com/en-us/azure/automation/overview)
* [Azure Monitor Logs](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-platform-logs)
* [Azure Monitor Alerts](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)

### Architecture
![](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/images/monitor-ssl-certificate-expiration-architecture-diagram.drawio.png)

