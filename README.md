# Overview
This solution provides the ability to monitor multiple HTTPS enabled endpoints and send alerts in case the presented SSL certificates come within a certain threshold of expiring. The solution uses the following Azure Services:

* [Azure Automation](https://docs.microsoft.com/en-us/azure/automation/overview)
* [Azure Monitor Logs](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-platform-logs)
* [Azure Alerts](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)

##	Problem Statement
SSL certificates have a predetermined validity period (usually 2 years or less) at the end of which the certificate is no longer considered usable. The impact of using an expired certificate varies depending on application behavior - web browsers may present a warning message to the end user allowing opting in/out, while other client applications will usually reject the certificate causing the SSL handshake to fail and therefore breaking the client/server flow.

The certificate renewal process itself, as well as any necessary endpoint re-configurations, are usually not automated tasks so it is critical that these are triggered with enough time ahead of the certificate expiration date.

Although CAs and other services responsible for emitting SSL certificates will send expiration notifications at predefined intervals (starting at 90 days out) certificate management can easily become a challenge for most organizations. It is often the case that site admins and other operations personnel do not have adequate visibility over the validity status of all the SSL certificates used across their application ecosystem.

## Solution Design

![](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/images/monitor-ssl-certificate-expiration-architecture-diagram.drawio.png)

This solution consists of: 

* A Log Analytics Workspace which will be used to store the monitored SSL certificate data

* An Azure Automation Account containing:

  * The following Variables:

    * List of HTTPS endpoint URLs to monitor
    * Log Analytics Workspace ID
    * Log Analytics Primary Key

  * A Runbook consisting of a PowerShell script which executes the following steps for each URL:

    * executes an HTTP GET request on the URL in order to retrieve the SSL certificate
    * parses the certificate and calculates the number of days remaining until certificate expiration
    * sends an entry to Log Analytics Workspace containing the URL and the number of days calculated in previous step

  * A Schedule which specifies the Runbook's recurring (daily) execution

* One or more Azure Alert rules based on Log Analytics queries which fire alerts based on the results 

# Deployment Steps

## Create Log Analytics Workspace

If you don't already have a Log Analytics Workspace available, you can quickly create one by following the instructions in [Create a Log Analytics workspace in the Azure portal](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace).

## Create Automation Account

Create an Automation Account by following the instructions in [Create a standalone Azure Automation account](https://docs.microsoft.com/en-us/azure/automation/automation-create-standalone-account).

## Create Automation Account Variables

### logAnalyticsWorkspaceID

* Navigate to your Log Analytics Workspace -> *Agents Management* and copy the *Workspace ID* field:

![](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/images/LogAnalyticsWorkspace_WorkspaceID.jpg)

* Navigate to your Automation Account -> *Variables* -> *+ Add a variable* and provide the following values in the *New Variable* form:

  * Name: *logAnalyticsWorkspaceID*
  * Description: Optional
  * Type: *String*
  * Value: Paste the Workspace ID value copied from previous step
  * Encrypted: Optional

* Click *Create*.

### logAnalyticsPrimaryKey
  
* Navigate to your Log Analytics Workspace -> *Agents Management* and copy the *Primary Key* field.

![](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/images/LogAnalyticsWorkspace_PrimaryKey.jpg)

* Navigate to your Automation Account -> *Variables* -> *+ Add a variable* and provide the following values in the *New Variable* form:

  * Name: *logAnalyticsPrimaryKey*
  * Description: Optional
  * Type: *String*
  * Value: Paste the Primary Key value copied from previous step
  * Encrypted: *Yes*

* Click *Create*.

### urlList

* Navigate to your Automation Account -> *Variables* -> *+ Add a variable* and provide the following values in the *New Variable* form:
  
  * Name: *urlList*
  * Description: Optional
  * Type: *String*
  * Value: Insert the comma separated list of HTTPS endpoint URLs to monitor, e.g. 'https://www.microsoft.com,https://www.mydomain.com:8443,https://mail.google.com'
  * Encrypted: Optional

* Click *Create*.

## Create Runbook

* Navigate to your Automation Account -> *Runbooks* -> *+ Create a runbook* and provide the following values in the *Create a runbook* form:
  
  * Name: *GetSSLCertificateExpiration*
  * Runbook type: PowerShell
  * Runtime version: 5.1
  * Description: Optional

* Copy the contents of PowerShell script [GetSSLCertificateDaysToExpiry.ps1](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/GetSSLCertificateDaysToExpiry.ps1) into the Runbook.

* Click *Save*, *Publish* and *Yes* to confirm.

* Navigate to your Automation Account -> *Runbooks* -> *GetSSLCertificateExpiration* and click *Start* to run the task and confirm it completes without any errors.

* Navigate to your Automation Account -> *Runbooks* -> *GetSSLCertificateExpiration* -> *Schedules* -> *+ Add a schedule* -> *Link a schedule to your runbook" -> *+ Add a schedule* and provide the following values in the *New Schedule* form:

  * Name: *Run GetSSLCertificateExpiration runbook*
  * Description: Optional
  * Starts: Select current date and time
  * Timezone: Select appropriate timezone
  * Recurrence: *Recurring*
  * Recur every: *1 day*
  * Set expiration: *No* 

## Create Alert

You can combine different Log Queries and notification settings in order to implement different alerting strategies based on this setup. For example you can implement separate alerts for each of the monitored URLs or a single alert which includes all URLs. You can also configure different severity levels for different endpoints (eg: Prod Vs Non-Prod) or send notifications to specific recipients depending on the URL of the certificate which is about to expire (if for example specific operations teams are responsible for renewing each of the certificates).

The following steps describe a simple example of such an Alert Rule which will trigger an email notification to an operations admin account as long as there is at least 1 certificate with under 90 days left until expiration.

* Navigate to your Log Analytics Workspace -> *Alerts* -> *+ New alert rule*. In the *Select a signal* form select *Custom log search*:

![](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/images/Alert_SelectSignal.jpg)

* In the Log Query editor insert the following query:

```
CertificateExpiration_CL
| where certExpiresIn_d <= 90 
| where TimeGenerated > ago(1d)
| summarize arg_max(TimeGenerated,*) by url_s
```

* Click *Run* and *Continue Editing Alert*.

* Provide the following values for the remaining parameters in the *Condition* form:
  
  * Measurement
    * Measure: *Table rows*
    * Measurement -> Aggregation Type: *Count*
    * Measurement -> Aggregation granularity: *1 day*
  * Split by dimensions
    * Resource ID column: *Don't split*
    * Dimension name: Leave empty
  * Alert logic
    * Operator: *Greater than*
    * Threshold value: *0*
    * Frequency of evaluation: *1 day*
  * Advanced options:
    * Number of violations: *1*
    * Evaluation period: *1day*
    * Override query time range: *None (1 day)*
 
* Click *Next: Actions*, and *Create action group*:

![](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/images/Alert_CreateActionGroup.jpg)

* Provide the following values in the *Basics* form:

  * Action group name: *mail admins*
  * Display name: *mail admins*

* Click *Next: Notifications* and provide the following values in the *Notifications* form:

  * Notification type: *Email/SMS message/Push/Voice*
  * Name: *send email"

* In the *Email/SMS message/Push/Voice* form check the *Email* option and provide the email address which should receive the email alert notifications:

![](https://github.com/jotavar/monitor-ssl-certificate-expiration/blob/master/images/Alert_CreateActionGroup_Notifications.jpg)

* Click *OK*, *Review + create* and *Create* to finalize the action group creation.

* Once the Action Group is created you will be redirected back to the *Create alert rule* form. Click *Next: Details*.

* Provide the following values for the remaining parameters in the *Condition* step of the Alert creation wizard:

  * Alert rule details
    * Severity: *2 - Warning*
    * Alert rule name: *Monitor SSL Certificate Expiration*
    * Alert rule description: Optional
  * Advanced options:
    * Enable upon creation: Yes
    * Mute Actions: No
    * Check workspace linked storage: No
 
* Click *Review + create* and *Create* to finalize Alert Rule creation.



