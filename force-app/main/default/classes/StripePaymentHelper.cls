public class StripePaymentHelper {

    private static final String STRIPE_API_KEY = 'sk_test_6ujXk2Ie32MNhcZynCVEgwQ400BjiXNttS'; // Replace with your Stripe secret key
    private static final String STRIPE_API_URL = 'https://api.stripe.com/v1/payment_links';

    // Make the createPaymentLink method invocable
    @InvocableMethod(label='Create Payment Link' description='Create a Stripe payment link for a Work Order')
    public static List<String> createPaymentLink(List<WorkOrderIdWrapper> workOrderIds) {
        List<String> paymentLinks = new List<String>();
        
        for (WorkOrderIdWrapper wrapper : workOrderIds) {
            // Assuming that the wrapper contains the Work Order Id
            String paymentLink = createPaymentLinkForWorkOrder(wrapper.woId);
            paymentLinks.add(paymentLink);
        }
        
        return paymentLinks; // Return the payment link URL(s)
    }
    
    public static String createPaymentLinkForWorkOrder(String woId) {
        
        // Retrieve related Work Order Items (Products)
        List<WorkOrderLineItem> workOrderItems = [SELECT Id, TotalPrice,Quantity , Product2.Stripe_Price_ID__c FROM WorkOrderLineItem WHERE WorkOrderId = :woId];
        
        // Check if there are Work Order Items
        if (workOrderItems.isEmpty()) {
            return 'This work order dont have any produts assigned so please wait ';  // If no items are found, return null or handle appropriately
        }
        
        // Prepare the parameters for the payment link
        String params = '';
        Integer itemIndex = 0;
        
        for (WorkOrderLineItem item : workOrderItems) {
            // Retrieve the Stripe Price ID from the custom field
            String stripePriceId = item.Product2.Stripe_Price_ID__c;  // Assuming the Price ID is stored in the custom field
            
            if (stripePriceId != null) {
                // Convert the price from Salesforce to the smallest currency unit (e.g., cents for USD)
                Integer priceInCents = Integer.valueOf(item.TotalPrice * 100);
                Integer stripeQuantity = item.Quantity!=null?Integer.valueOf(item.Quantity):1;
                
                // Append the line item information for Stripe
                params += 'line_items[' + itemIndex + '][price]=' + stripePriceId + '&';
                params += 'line_items[' + itemIndex + '][quantity]='+stripeQuantity +'&'; // Default quantity = 1
                
                itemIndex++;
            }
        }
        
        // Remove the last "&" from the parameters
        params = params.substring(0, params.length() - 1);
        params += '&metadata[work_order_id]=' + woId;  // Pass Work Order ID in metadata

        
        // Make the API request to create the payment link
        HttpRequest req = new HttpRequest();
        req.setEndpoint(STRIPE_API_URL);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + STRIPE_API_KEY);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(params);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Handle the response
        if (res.getStatusCode() == 200) {
            // Parse the response and get the payment link URL
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String paymentLink = (String) responseMap.get('url');
            String paymentLinkId = (String) responseMap.get('id');
            
            WorkOrder wo = new WorkOrder(Id=woId);
           	wo.Payment_Link__c = paymentLink; // Assuming you have a custom field for Payment Link
            wo.Payment_Link_ID__c = paymentLinkId; // Assuming you have a custom field for Payment Link ID
            update wo;
            
          
            return paymentLink;
        } else {
            System.debug('Error: ' + res.getBody());
            return null;
        }
    }
    
    // Wrapper class to pass Work Order Id to Flow
    public class WorkOrderIdWrapper {
        @InvocableVariable
        public String woId;
    }
}