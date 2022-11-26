public with sharing class FlowScheduledReportHandler {

    @InvocableMethod(
        label='Email Report' 
        category='Reporting' 
        description='Report will be emailed as an attached file')
    public static List<Result> emailReport(List<Request> lstRequests) {
        String responseMessage = '';

        String reportName = lstRequests.get(0).reportName;
        String toAddresses = lstRequests.get(0).toAddresses;
        String subject = lstRequests.get(0).subject;
        String body = lstRequests.get(0).body;
        String senderDisplayName = lstRequests.get(0).senderDisplayName;
        String fileType = lstRequests.get(0).fileType.toLowerCase();

        try {
            ReportSubscriptionHandler.emailData(
                reportName, 
                toAddresses, 
                subject, 
                body, 
                senderDisplayName, 
                fileType
            );
            responseMessage = 'Success';
        } catch (Exception e) {
            responseMessage = 'Received error: ' + e.getMessage();
        }

        Result result = new Result();
        result.responseMessage = responseMessage;
        return new List<Result>{ result };

    }
    
    public class Request {
        @InvocableVariable(required=true label='Name of Report')
        public String reportName;

        @InvocableVariable(required=true label='To Addresses' description='Use comma separated string')
        public String toAddresses;

        @InvocableVariable(required=true label='Email Subject')
        public String subject;

        @InvocableVariable(required=true label='Email Body')
        public String body;

        @InvocableVariable(required=true label='Sender Display Name')
        public String senderDisplayName;

        @InvocableVariable(required=true label='File Type' description='Valid values are csv, xls, and xlsx')
        public string fileType;
    }

    public class Result {
        @InvocableVariable(label='Response Message')
        public String responseMessage;
    }
}
