public with sharing class ProductCatalogController {
    private static final String DEFAULT_IMAGE = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgdmlld0JveD0iMCAwIDIwMCAyMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPHJlY3Qgd2lkdGg9IjIwMCIgaGVpZ2h0PSIyMDAiIGZpbGw9IiNGOEY5RkEiLz4KICA8cGF0aCBkPSJNNjAgNDBIMTQwQzE1MCA0MCAxNjAgNTAgMTYwIDYwVjE0MEMxNjAgMTUwIDE1MCAxNjAgMTQwIDE2MEg2MEM1MCAxNjAgNDAgMTUwIDQwIDE0MFY2MEM0MCA1MCA1MCA0MCA2MCA0MFoiIGZpbGw9IiNFNUU3RUIiLz4KICA8cGF0aCBkPSJNODAgNjBIMTIwQzEyNSA2MCAxMzAgNjUgMTMwIDcwVjEzMEMxMzAgMTM1IDEyNSAxNDAgMTIwIDE0MEg4MEM3NSAxNDAgNzAgMTM1IDcwIDEzMFY3MEM3MCA2NSA3NSA2MCA4MCA2MFoiIGZpbGw9IiMyQjgyRjYiLz4KICA8cGF0aCBkPSJNOTAgODBIMTEwQzExMiA4MCAxMTQgODIgMTE0IDg0Vjg2QzExNCA4OCAxMTIgOTAgMTEwIDkwSDkwQzg4IDkwIDg2IDg4IDg2IDg2Vjg0Qzg2IDgyIDg4IDgwIDkwIDgwWiIgZmlsbD0iI0YwRjdGRiIvPgogIDxwYXRoIGQ9Ik05MCAxMDBIMTEwQzExMiAxMDAgMTE0IDEwMiAxMTQgMTA0VjEwNkMxMTQgMTA4IDExMiAxMTAgMTEwIDExMEg5MEM4OCAxMTAgODYgMTA4IDg2IDEwNlYxMDRDODYgMTAyIDg4IDEwMCA5MCAxMDBaIiBmaWxsPSIjRjBGN0ZGIi8+CiAgPHBhdGggZD0iTTkwIDEyMEgxMTBDMTEyIDEyMCAxMTQgMTIyIDExNCAxMjRWMTI2QzExNCAxMjggMTEyIDEzMCAxMTAgMTMwSDkwQzg4IDEzMCA4NiAxMjggODYgMTI2VjEyNEM4NiAxMjIgODggMTIwIDkwIDEyMFoiIGZpbGw9IiNGMEY3RkYiLz4KPC9zdmc+';
    
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
            this.imageUrl = pbe.Product2.DisplayUrl != null && pbe.Product2.DisplayUrl.trim() != '' ? 
                pbe.Product2.DisplayUrl : DEFAULT_IMAGE;
            this.pricebookEntryId = pbe.Id;
        }
    }
}