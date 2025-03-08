public with sharing class WorkOrderItemController {
    @AuraEnabled
    public static void createWorkOrderItem(Id workOrderId, Id productId, Decimal quantity) {
        try {
            // Get the Work Order's Pricebook
            WorkOrder wo = [
                SELECT Id, Pricebook2Id, Status, WorkOrderNumber 
                FROM WorkOrder 
                WHERE Id = :workOrderId 
                LIMIT 1
            ];
            
            // Get the PricebookEntry for the product
            PricebookEntry pbe = [
                SELECT Id, UnitPrice, Product2.Name 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :wo.Pricebook2Id 
                AND Product2Id = :productId 
                AND IsActive = true 
                LIMIT 1
            ];
            
            // Create the Work Order Line Item
            WorkOrderLineItem lineItem = new WorkOrderLineItem(
                WorkOrderId = workOrderId,
                PricebookEntryId = pbe.Id,
                Quantity = quantity,
                UnitPrice = pbe.UnitPrice,
                Description = 'AI Recommended Product: ' + pbe.Product2.Name,
                Status = wo.Status  // Inherit status from Work Order
            );
            
            insert lineItem;
            
        } catch (Exception e) {
            String errorMsg = 'Error creating Work Order Line Item: ';
            
            // Handle specific error cases
            if (e.getMessage().contains('FIELD_INTEGRITY_EXCEPTION')) {
                errorMsg += 'Unable to find valid price for this product in the Work Order\'s price book.';
            } else {
                errorMsg += e.getMessage();
            }
            
            throw new AuraHandledException(errorMsg);
        }
    }
} 