@RestResource(urlMapping='/stripeWorkOrderWebhook/*')
global without sharing class StripeWorkOrderAPI {

    @HttpGet
    global static string performGet(){
        return '';
    }

    @HttpPost
    global static void updateWorkOrder() {
        // Get the request body directly from RestRequest
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();

        // Debug the request body
        System.debug('Request body: ' + body);
        
        // Parse the incoming JSON body into a Map
        Map<String, Object> parsedBody = (Map<String, Object>)JSON.deserializeUntyped(body);

        // Access the 'data' key and then 'object' key from the Map
        Map<String, Object> dataObject = (Map<String, Object>)parsedBody.get('data');
        Map<String, Object> checkoutSessionObject = (Map<String, Object>)dataObject.get('object');

        // Access 'metadata' and 'work_order_id' from the nested objects
        Map<String, Object> metadata = (Map<String, Object>)checkoutSessionObject.get('metadata');
        String workOrderId = (String)metadata.get('work_order_id');

        // Query the WorkOrder record based on the extracted work_order_id
        WorkOrder wo = [SELECT Id, Status,Stripe_Webhook_Resp__c FROM WorkOrder WHERE Id = :workOrderId LIMIT 1];

        // Update the WorkOrder status
        wo.Status = 'Payment Received';
        wo.Stripe_Webhook_Resp__c = body;

        // Update the WorkOrder record
        update wo;
    }
}