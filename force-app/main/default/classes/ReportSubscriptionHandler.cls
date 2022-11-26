public with sharing class ReportSubscriptionHandler {

    private static Map<Id, Report> mapCachedReports;

    /**
     * @Description emailData - method sends csv as email attachment from 
     *   report subscription metadata
     * @param Report_Subscription__mdt[] lstSubs - a list of report subscription metadata records
     */

    public static void emailData(
        List<Report_Subscription__mdt> lstSubs
    ) {
        Set<String> setFieldNames = new Set<String>();
        for (Report_Subscription__mdt sub : lstSubs) {
            setFieldNames.add(sub.Column_1__c);
            setFieldNames.add(sub.Column_2__c);
            setFieldNames.add(sub.Column_3__c);
            setFieldNames.add(sub.Column_4__c);
        }

        // Get list of metadata fields
        List<FieldDefinition> lstFields = [
            SELECT DurableId, QualifiedApiName FROM FieldDefinition WHERE DurableId IN :setFieldNames LIMIT 10000
        ];

        Map<String, String> mapFieldToApiName = new Map<String, String>();
        for (FieldDefinition fieldDef : lstFields) {
            mapFieldToApiName.put(fieldDef.DurableId, fieldDef.QualifiedApiName);
        }

        for (Report_Subscription__mdt sub : lstSubs) {
            String queryString = 'SELECT ';
            String header = '';
            header += sub.Column_1__c != null ? mapFieldToApiName.get(sub.Column_1__c) + ',' : '';
            header += sub.Column_2__c != null ? mapFieldToApiName.get(sub.Column_2__c) + ',' : '';
            header += sub.Column_3__c != null ? mapFieldToApiName.get(sub.Column_3__c) + ',' : '';
            header += sub.Column_4__c != null ? mapFieldToApiName.get(sub.Column_4__c) + ',' : '';
            queryString += header.removeEnd(',') + ' FROM ' + sub.Source_Object__c + ' WHERE ' + sub.Filter_Criteria__c;

            // get data
            List<sObject> lstObjects = Database.query(queryString);

            String finalstr = header + '\n';
            for (sObject obj : lstObjects) {
                String recordString = 
                    (String)obj.get(mapFieldToApiName.get(sub.Column_1__c)) + ',' + 
                    (String)obj.get(mapFieldToApiName.get(sub.Column_2__c)) + ',' +
                    (String)obj.get(mapFieldToApiName.get(sub.Column_3__c)) + ',' + 
                    (String)obj.get(mapFieldToApiName.get(sub.Column_4__c)) + 
                    '\n';
                finalstr = finalstr + recordString;
            }

            // Create csv email attachment
            Messaging.EmailFileAttachment csvAttc = new Messaging.EmailFileAttachment();
            Blob csvBlob = Blob.valueOf(finalstr);
            String csvName = 'MetadataReportSubscription.csv';
            csvAttc.setFileName(csvName);
            csvAttc.setBody(csvBlob);

            // Email result as attachment
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            String[] toAddresses = new list<String> { 
                'sserkin@asphaltgreen.org', 'stefanserkin+mdtreports@gmail.com'
            };
            String subject ='Metadata Report Subscription CSV';
            email.setSubject(subject);
            email.setToAddresses(toAddresses);
            email.setPlainTextBody('Metadata Report Subscription CSV ');
            email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ 
                csvAttc 
            });
            Messaging.SendEmailResult[] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});

        }

    }

    /**
     * @Description emailData - method also accepts a report name to email the report
     *   as an attachment
     * @param String reportName - the name of the report
     * @param String toAddresses - the recipients of the email
     * @param String subject - the subject of the email message
     * @param String body - the plain text body of the email message
     * @param String displayName - display name for sender
     */

    @future(callout=true)
    public static void emailData(
        String reportName, 
        String toAddresses, 
        String subject, 
        String body, 
        String senderDisplayName
    ) {
        // Get report from provided name
        Report report = [SELECT Id, Name FROM Report WHERE Name = :reportName OR DeveloperName = :reportName LIMIT 1];
        String reportId = report != null ? report.Id : null;
        String reportDisplayName = report != null ? report.Name : null;

        // Get report content using java servlet
        String instanceName = URL.getSalesforceBaseUrl().toExternalForm();
        String url = instanceName + '/servlet/PrintableViewDownloadServlet?isdtp=p1&reportId=' + reportId;
        ApexPages.PageReference objPage = new ApexPages.PageReference(url);
        Blob reportContent = objPage.getContent();

        // Create attachment
        Messaging.EmailFileAttachment objMsgEmailAttach = new Messaging.EmailFileAttachment();
        objMsgEmailAttach.setFileName(reportDisplayName + '.csv');
        objMsgEmailAttach.setBody(reportContent);
        objMsgEmailAttach.setContentType('text/csv');

        // Create email from input
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        List<String> lstToAddresses = toAddresses.split(',');
        email.setToAddresses(lstToAddresses);
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setSenderDisplayName(senderDisplayName);
        email.setFileAttachments(
            new List<Messaging.EmailFileAttachment>{ 
                objMsgEmailAttach 
            }
        );

        // Send email
        Messaging.SendEmailResult[] r = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{
                email
            }
        );
    }

}
