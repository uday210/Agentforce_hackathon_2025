public class StripeProductHelper {
    
    private static final String STRIPE_API_KEY = 'sk_test_6ujXk2Ie32MNhcZynCVEgwQ400BjiXNttS'; // Replace with your Stripe secret key
    private static final String STRIPE_API_URL = 'https://api.stripe.com/v1/products';
    private static final String STRIPE_PRICE_URL = 'https://api.stripe.com/v1/prices';

     // Method to push products to Stripe, create prices, and update Salesforce with Price IDs
    public static void createStripeProductsAndPrices() {
        // Query Salesforce Product2 records
        List<Product2> products = [SELECT Id, Name,Stripe_Price_ID__c FROM Product2 WHERE Stripe_Price_ID__c=null LIMIT 25]; // Adjust the limit if needed
        
        List<PricebookEntry> pricebookEntriesToInsert = new List<PricebookEntry>();
     
        // Step 2: Perform the callout to create the product on Stripe and set prices
        List<String> priceIds = new List<String>();
        for (Product2 product : products) {
            // Push product to Stripe and get the Price ID
            String priceId = createStripeProductAndPrice(product);
            
            if (priceId != null) {
                // Step 3: Update Salesforce Product2 records with the Stripe Price ID
                product.Stripe_Price_ID__c = priceId; // Assuming you have a custom field Stripe_Price_ID__c on Product2
                priceIds.add(priceId);
            }
        }
        
        // Update Salesforce records with Price IDs after the callout
        if (!products.isEmpty()) {
            update products;
        }
    }
    
    // Create product and price on Stripe and return the price ID
    public static String createStripeProductAndPrice(Product2 product) {
        
        // Fetch the standard price from PricebookEntry (assuming you want the default Pricebook)
        PricebookEntry pricebookEntry = [SELECT UnitPrice, Pricebook2.Name FROM PricebookEntry WHERE Product2Id = :product.Id AND Pricebook2.Name ='Leak Fix Services/Products' LIMIT 1];
        
        if (pricebookEntry == null) {
            // Handle case if PricebookEntry is not found
            System.debug('Error: PricebookEntry not found for product ' + product.Name);
            return null;
        }
        
        // Get the unit price from the PricebookEntry
        Decimal unitPrice = pricebookEntry.UnitPrice; // Unit price from the PricebookEntry
        
        if (unitPrice == null) {
            // Handle case if unit price is missing
            System.debug('Error: Unit price is not set for product ' + product.Name);
            return null;
        }
        
        // Prepare the product data
        String productParams = 'name=' + EncodingUtil.urlEncode(product.Name, 'UTF-8');
        
        // Make the API call to create the product on Stripe
        HttpRequest req = new HttpRequest();
        req.setEndpoint(STRIPE_API_URL);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + STRIPE_API_KEY);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(productParams);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Check if the product creation was successful
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String productId = (String) responseMap.get('id');
            
            // Now create a price for the product (using the Unit Price from PricebookEntry)
            String priceParams = 'unit_amount=' + (unitPrice * 100).intValue() +  // Price in cents (multiply by 100)
                                 '&currency=usd&product=' + productId; // Price in cents (1000 = $10)
            
            // Create price for the product
            HttpRequest priceReq = new HttpRequest();
            priceReq.setEndpoint(STRIPE_PRICE_URL);
            priceReq.setMethod('POST');
            priceReq.setHeader('Authorization', 'Bearer ' + STRIPE_API_KEY);
            priceReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            priceReq.setBody(priceParams);
            
            HttpResponse priceRes = http.send(priceReq);
            
            if (priceRes.getStatusCode() == 200) {
                Map<String, Object> priceResponseMap = (Map<String, Object>) JSON.deserializeUntyped(priceRes.getBody());
                String priceId = (String) priceResponseMap.get('id');
                
                // Return the price ID
                return priceId;
            } else {
                System.debug('Error creating price for product: ' + priceRes.getBody());
            }
        } else {
            System.debug('Error creating product: ' + res.getBody());
        }
        
        return null;
    }
}