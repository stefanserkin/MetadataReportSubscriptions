public with sharing class FlowScheduledReportHandler {

    @InvocableMethod(
        label='Email Report' 
        category='Reporting' 
        description='Report will be emailed as an attached file')
    public static List<Result> emailReport(List<Request> lstRequests) {
        String responseMessage = '';

        String reportName = lstRequests.get(0).reportName != null ? lstRequests.get(0).reportName : null;
        String toAddresses = lstRequests.get(0).toAddresses != null ? lstRequests.get(0).toAddresses : null;
        String subject = lstRequests.get(0).subject != null ? lstRequests.get(0).subject : null;
        String body = lstRequests.get(0).body != null ? lstRequests.get(0).body : null;
        String senderDisplayName = lstRequests.get(0).senderDisplayName != null ? lstRequests.get(0).senderDisplayName : null;

        try {
            ReportSubscriptionHandler.emailData(
                reportName, 
                toAddresses, 
                subject, 
                body, 
                senderDisplayName
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
    }

    public class Result {
        @InvocableVariable(label='Response Message')
        public String responseMessage;
    }
}
