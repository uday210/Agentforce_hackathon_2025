public with sharing class ProductCatalogController {
    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getProducts() {
        // Get the Pricebook Id
        Pricebook2 standardPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Leak Fix Services/Products' LIMIT 1];
        
        // Query PricebookEntries with related Product information
        List<PricebookEntry> entries = [
            SELECT Id, UnitPrice, Product2Id, Product2.Name, Product2.Description, 
                   Product2.DisplayUrl, Product2.Family
            FROM PricebookEntry 
            WHERE Pricebook2Id = :standardPb.Id 
            AND Product2.Family = 'Product'
            AND IsActive = true
        ];
        
        List<ProductWrapper> wrappers = new List<ProductWrapper>();
        for(PricebookEntry pbe : entries) {
            wrappers.add(new ProductWrapper(pbe));
        }
        
        return wrappers;
    }
    
    public class ProductWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal price;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public String pricebookEntryId;
        
        public ProductWrapper(PricebookEntry pbe) {
            this.id = pbe.Product2Id;
            this.name = pbe.Product2.Name;
            this.description = pbe.Product2.Description;
            this.price = pbe.UnitPrice.setScale(2);
            this.imageUrl = pbe.Product2.DisplayUrl != null ? pbe.Product2.DisplayUrl : '/resource/DefaultProductImage';
            this.pricebookEntryId = pbe.Id;
        }
    }
}