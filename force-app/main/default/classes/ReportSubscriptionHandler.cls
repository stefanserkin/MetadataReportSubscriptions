public with sharing class ReportSubscriptionHandler {

    private static Map<Id, Report> mapCachedReports;

    private static final String FILE_TYPE_CSV = 'csv';
    private static final String FILE_TYPE_EXCEL = 'xls';
    private static final String FILE_TYPE_EXCEL_WORKBOOK = 'xlsx';
    private static final String CONTENT_TYPE_CSV = 'text/csv';
    private static final String CONTENT_TYPE_EXCEL = 'application/vnd.ms-excel';
    private static final String ERROR_INVALID_TYPE = 'Must provide a valid file type (csv, xls, or xlsx)';

    private static final String SUBSCRIPTION_TYPE_METADATA = 'Metadata Relationships';
    private static final String SUBSCRIPTION_TYPE_SOQL = 'SOQL Query';

    /**
     * @Description emailData - async method emails a report as an attachment to a group of users
     * @param String reportName - the name of the report
     * @param String toAddresses - the recipients of the email
     * @param String subject - the subject of the email message
     * @param String body - the plain text body of the email message
     * @param String displayName - display name for sender
     * @param String contentType - valid values: ['csv','xls','xlsx'];
     */

    @future(callout=true)
    public static void emailData(
        String reportName, 
        String toAddresses, 
        String subject, 
        String body, 
        String senderDisplayName, 
        String fileType
    ) {
        // Get report from provided name
        Report report = [
            SELECT Id, Name, DeveloperName 
              FROM Report 
             WHERE Name = :reportName OR DeveloperName = :reportName 
             LIMIT 1
        ];
        
        // Create attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        ApexPages.PageReference objPage;

        if (fileType.toLowerCase() == FILE_TYPE_CSV) {
            // For csv files, specify encoding in relative url
            objPage = new ApexPages.PageReference('/' + report.Id + '?csv=1&exp=1&enc=UTF-8&isdtp=p1');
        } else if (
            fileType.toLowerCase() == FILE_TYPE_EXCEL || 
            fileType.toLowerCase() == FILE_TYPE_EXCEL_WORKBOOK
        ) {
            // For xls and xlsx, get report content using java servlet 
            String instanceName = URL.getSalesforceBaseUrl().toExternalForm();
            String url = instanceName + '/servlet/PrintableViewDownloadServlet?isdtp=p1&reportId=' + report.Id;
            objPage = new ApexPages.PageReference(url);
        } else {
            throw new ReportSubscriptionException(ERROR_INVALID_TYPE);
        }

        attachment.setBody(objPage.getContent());
        attachment.setFileName(report.DeveloperName + '.' + fileType.toLowerCase());
        attachment.setContentType(fileType.toLowerCase().left(3) == FILE_TYPE_EXCEL ? CONTENT_TYPE_EXCEL : CONTENT_TYPE_CSV);

        // Create email from input
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        List<String> lstToAddresses = toAddresses.split(',');
        email.setToAddresses(lstToAddresses);
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setSenderDisplayName(senderDisplayName);
        email.setFileAttachments(
            new List<Messaging.EmailFileAttachment>{ 
                attachment 
            }
        );

        // Send email
        Messaging.SendEmailResult[] r = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{
                email
            }
        );
    }

    /**
     * @Description emailData - sends csv as email attachment based on report subscription metadata
     * @param Report_Subscription__mdt[] lstSubs - a list of report subscription metadata records
     */

    public static void emailData(
        List<Report_Subscription__mdt> lstSubs
    ) {
        List<Report_Subscription__mdt> lstMetadataSubs = new List<Report_Subscription__mdt>();
        // Separate subscriptions by type
        for (Report_Subscription__mdt sub : lstSubs) {
            if (sub.Type__c == SUBSCRIPTION_TYPE_METADATA) {
                lstMetadataSubs.add(sub);
            } else if (sub.Type__c == SUBSCRIPTION_TYPE_SOQL) {
                emailSoqlData(sub);
            }
        }

        Set<String> setFieldNames = new Set<String>();
        for (Report_Subscription__mdt sub : lstMetadataSubs) {
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

        for (Report_Subscription__mdt sub : lstMetadataSubs) {
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

            sendEmailFromCsvString(
                finalstr, 
                sub
            );

        }
    }

    /**
     * @description emailSoqlData - for metadata records with defined queries
     * @param String headersCsv - a csv string of column headers
     * @param String fieldApiNamesCsv - a csv string of field api names - must match headers
     * @param String query - the soql query with records to retrieve
     */

    public static void emailSoqlData(
        Report_Subscription__mdt sub
    ) {
        List<sObject> lstSObjects = Database.query(sub.SOQL_Query__c);
        List<String> lstFieldApiNames = sub.Field_API_Names_CSV__c.split(',');

        Integer rowListSize = 0; // lstSObjects.size();
        Integer headerSize = sub.Headers_CSV__c.split(',').size();

        // Begin csv string with row of headers
        String resultCsv = sub.Headers_CSV__c + '\n';

        // Add each row from query results
        Integer recordCount = 0;
        for (SObject sObj : lstSObjects) {
            Map<String, Object> mapObjFields = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(sObj));
            Integer fieldCount = 0;
            for (String field : lstFieldApiNames) {
                resultCsv += mapObjFields.get(field) != null ? String.valueOf(mapObjFields.get(field)) : '';
                fieldCount++;
                resultCsv += fieldCount != headerSize ? ',' : '';
            }
            recordCount++;
            resultCsv += recordCount != rowListSize ? '\n' : '';
        }

        sendEmailFromCsvString(
            resultCsv, 
            sub
        );

    }

    /**
     * @description sendEmailFromCsvString - assembles email with attached csv and emails
     *   it to provided to addresses
     * @param String csvString - csv data to be included in attachment
     * @param Report_Subscription__mdt sub - report subscription configuration
     */

    private static void sendEmailFromCsvString(
        String csvString, 
        Report_Subscription__mdt sub
    ) {
        // Create csv email file attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(sub.Output_File_Name__c + '.csv');
        attachment.setBody(Blob.valueOf(csvString));

        // Email result as attachment
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(sub.To_Addresses__c.split(','));
        email.setSubject(sub.Email_Subject__c);
        email.setPlainTextBody(sub.Email_Body__c);
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ 
            attachment 
        });
        List<Messaging.SendEmailResult> result = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage> {
                email
            }
        );
    }

    /**
     * Custom exception
     */

    public class ReportSubscriptionException extends Exception {}

}
