public with sharing class ReportSubscriptionBatch implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Type__c, To_Addresses__c, Email_Subject__c, Email_Body__c, Output_File_Name__c, Source_Object__c, Column_1__c, Column_2__c, Column_3__c, Column_4__c, Filter_Criteria__c, SOQL_Query__c, Headers_CSV__c, Field_API_Names_CSV__c FROM Report_Subscription__mdt LIMIT 10000';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Report_Subscription__mdt> lstSubs) {
        ReportSubscriptionHandler.emailData(
            lstSubs
        );
    }

    public void finish(Database.BatchableContext bc) {
        AsyncApexJob apexJob = [
            SELECT Id, 
                   Status, 
                   NumberOfErrors, 
                   JobItemsProcessed, 
                   TotalJobItems, 
                   CreatedBy.Email
              FROM AsyncApexJob 
             WHERE Id = :bc.getJobId()
        ];
        
        // Send email to job creator with batch results
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        String[] toAddress = new String[] {apexJob.CreatedBy.Email};
        email.setToAddresses(toAddress);
        email.setSubject(apexJob.Status + ': Report Subscription Batch');
        email.setPlainTextBody('The Report Subscription ran and processed ' + apexJob.TotalJobItems + ' batches with ' + apexJob.NumberOfErrors + ' failures. Job Id: ' + apexJob.Id);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }

}
