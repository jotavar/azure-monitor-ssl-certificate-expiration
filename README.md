# 1	Overview
This solution provides the ability to monitor multiple HTTPS enabled endpoints and send alerts in case the presented SSL certificates come within a certain threshold of expiring.

# 2	Problem Statement
SSL certificates have a predetermined validity period (usually 2 years or less) at the end of which the certificate will no longer be considered valid. The impact of using an expired certificate varies depending on the client application behavior - web browsers may present a warning message to the end user allowing opting in or out, while other client applications will usually reject the certificate causing the SSL handshake to fail, therefore breaking the client/server flow.

Certificate management can easili become a challenge for most organizations as it is often the case that site admins and other operations personnel do not have adequate visibility over the validity status of the SSL certificates used in their live environments.     
