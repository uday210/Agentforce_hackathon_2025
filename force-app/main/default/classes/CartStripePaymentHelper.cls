public with sharing class CartStripePaymentHelper {
    private static final String STRIPE_SECRET_KEY = 'sk_test_6ujXk2Ie32MNhcZynCVEgwQ400BjiXNttS';
    private static final String STRIPE_API_URL = 'https://api.stripe.com/v1/';
    
    public static String generatePaymentLink(Id cartId) {
        Cart__c cart = [
            SELECT Id, Total_Amount__c, 
                   (SELECT Id, Product__c, Product__r.Stripe_Price_ID__c, Quantity__c 
                    FROM Cart_Items__r)
            FROM Cart__c 
            WHERE Id = :cartId
        ];
        
        // Prepare line items for Stripe
        List<Map<String, Object>> lineItems = new List<Map<String, Object>>();
        for(CartItem__c item : cart.Cart_Items__r) {
            Map<String, Object> lineItem = new Map<String, Object>{
                'price' => item.Product__r.Stripe_Price_ID__c,
                'quantity' => Integer.valueOf(item.Quantity__c)
            };
            lineItems.add(lineItem);
        }
        
        // Create payment link in Stripe
        HttpRequest req = new HttpRequest();
        req.setEndpoint(STRIPE_API_URL + 'payment_links');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + STRIPE_SECRET_KEY);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String body = 'line_items[0][price]=' + lineItems[0].get('price') +
                     '&line_items[0][quantity]=' + lineItems[0].get('quantity');
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if(res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            String paymentLink = (String)responseMap.get('url');
            
            // Update cart with payment link
            cart.Payment_Link__c = paymentLink;
            cart.Status__c = 'Payment Pending';
            update cart;
            
            return paymentLink;
        } else {
            throw new CartStripeException('Failed to create payment link: ' + res.getBody());
        }
    }
    
    public class CartStripeException extends Exception {}
} 