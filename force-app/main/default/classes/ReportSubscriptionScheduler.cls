public with sharing class ReportSubscriptionScheduler implements Schedulable {

    public static String schedule = '0 30 0 ? * *'; // Every day at 12:30am

    public static String run() {
        ReportSubscriptionScheduler sched = new ReportSubscriptionScheduler();
        return System.schedule('Report Subscription Schedule', schedule, sched);
    }

    public void execute(SchedulableContext context) {
        ReportSubscriptionBatch batch = new ReportSubscriptionBatch();
        Id batchId = Database.executeBatch(batch, 50);
    }
    
}
