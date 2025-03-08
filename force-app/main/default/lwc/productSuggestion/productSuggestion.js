import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import invokePrompt from '@salesforce/apex/ProductSugessionFromPrompt.invokePrompt';
import createWorkOrderItem from '@salesforce/apex/WorkOrderItemController.createWorkOrderItem';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getExistingProductIds from '@salesforce/apex/WorkOrderItemController.getExistingProductIds';

export default class ProductSuggestion extends LightningElement {
    @api recordId;
    @track suggestions = [];
    @track isLoading = false;
    @track error;
    @track existingProductIds = [];

    connectedCallback() {
        this.refreshSuggestions();
    }

    @api
    async refreshSuggestions() {
        if (!this.recordId) return;
        
        this.isLoading = true;
        this.error = null;

        try {
            // First, get existing product IDs
            this.existingProductIds = await getExistingProductIds({ workOrderId: this.recordId });
            
            const result = await invokePrompt({ workOrderId: this.recordId });
            console.log('Raw response from prompt:', result);

            // Clean up the response to extract just the JSON array
            let cleanJson = result
                // Remove any non-JSON text before the array
                .replace(/^[^[]*/, '')
                // Remove any non-JSON text after the array
                .replace(/][^]]*$/, ']')
                // Replace single quotes with double quotes
                .replace(/'/g, '"')
                // Remove any newlines or extra spaces
                .replace(/\s+/g, ' ')
                .trim();
            
            console.log('Cleaned JSON string:', cleanJson);
            
            // Try to parse the cleaned JSON
            let parsedData;
            try {
                parsedData = JSON.parse(cleanJson);
            } catch (parseError) {
                console.error('JSON Parse Error:', parseError);
                // If parsing fails, try one more cleanup
                cleanJson = cleanJson
                    // Remove any potential trailing commas
                    .replace(/,\s*]/g, ']')
                    // Ensure property names are double-quoted
                    .replace(/([{,]\s*)(\w+)(\s*:)/g, '$1"$2"$3');
                
                console.log('Second attempt clean JSON:', cleanJson);
                try {
                    parsedData = JSON.parse(cleanJson);
                } catch (secondError) {
                    console.error('Second JSON Parse Error:', secondError);
                    throw new Error('Failed to parse product suggestions');
                }
            }
            
            console.log('Parsed data:', parsedData);
            
            // Validate the parsed data is an array
            if (!Array.isArray(parsedData)) {
                throw new Error('Invalid product suggestions format');
            }

            // Filter out products that are already in the Work Order
            this.suggestions = parsedData
                .filter(item => !this.existingProductIds.includes(item.ProductId))
                .map(item => ({
                    productName: item['Product Name'],
                    quantity: item.Quantity,
                    productId: item.ProductId,
                }));

            console.log('Processed suggestions:', this.suggestions);

        } catch (error) {
            console.error('Error in refreshSuggestions:', error);
            this.error = error.message || 'Error fetching suggestions';
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleAddToWorkOrder(event) {
        const suggestion = this.suggestions[event.currentTarget.dataset.index];
        const index = parseInt(event.currentTarget.dataset.index);
        
        try {
            await createWorkOrderItem({
                workOrderId: this.recordId,
                productId: suggestion.productId,
                quantity: suggestion.quantity
            });
            
            // Remove the added suggestion from the list
            this.suggestions = this.suggestions.filter((_, i) => i !== index);
            // Add to existing products list
            this.existingProductIds.push(suggestion.productId);
            
            this.showToast(
                'Success',
                `Added ${suggestion.productName} to work order`,
                'success'
            );

            // Notify Lightning Data Service to refresh the Work Order record
            getRecordNotifyChange([{recordId: this.recordId}]);

        } catch (error) {
            console.error('Error adding to work order:', error);
            this.showToast(
                'Error',
                error.message || 'Error adding product to work order',
                'error'
            );
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    handleQuantityChange(event) {
        const index = event.target.dataset.index;
        const newQuantity = parseInt(event.target.value, 10);
        
        if (newQuantity > 0) {
            this.suggestions = this.suggestions.map((item, i) => {
                if (i === parseInt(index)) {
                    return {
                        ...item,
                        quantity: newQuantity
                    };
                }
                return item;
            });
        }
    }
} 