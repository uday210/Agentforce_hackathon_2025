public with sharing class CartController {
    @AuraEnabled
    public static Map<String, String> createCart(Map<String, Object> cartData, List<Map<String, Object>> cartItems) {
        try {
            Decimal totalAmount;
            try {
                totalAmount = Decimal.valueOf(String.valueOf(cartData.get('Total_Amount__c')));
            } catch (Exception e) {
                totalAmount = 0;
            }
            
            // Create Cart record
            Cart__c cart = new Cart__c(
                Status__c = (String)cartData.get('Status__c'),
                Total_Amount__c = totalAmount,
                Billing_Street__c = (String)cartData.get('Billing_Street__c'),
                Billing_City__c = (String)cartData.get('Billing_City__c'),
                Billing_State__c = (String)cartData.get('Billing_State__c'),
                Billing_PostalCode__c = (String)cartData.get('Billing_PostalCode__c'),
                Billing_Country__c = (String)cartData.get('Billing_Country__c'),
                Shipping_Street__c = (String)cartData.get('Shipping_Street__c'),
                Shipping_City__c = (String)cartData.get('Shipping_City__c'),
                Shipping_State__c = (String)cartData.get('Shipping_State__c'),
                Shipping_PostalCode__c = (String)cartData.get('Shipping_PostalCode__c'),
                Shipping_Country__c = (String)cartData.get('Shipping_Country__c'),
                Contact_Email__c = (String)cartData.get('Contact_Email__c'),
                Contact_Phone__c = (String)cartData.get('Contact_Phone__c')
            );
            
            insert cart;
            
            // Create Cart Items
            List<CartItem__c> items = new List<CartItem__c>();
            for(Map<String, Object> item : cartItems) {
                items.add(new CartItem__c(
                    Cart__c = cart.Id,
                    Product__c = (String)item.get('id'),
                    Quantity__c = (Decimal)item.get('quantity'),
                    Unit_Price__c = (Decimal)item.get('price')
                ));
            }
            insert items;
            
            return new Map<String, String>{
                'cartId' => cart.Id
            };
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 