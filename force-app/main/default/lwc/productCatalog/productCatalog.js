import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProducts from '@salesforce/apex/ProductCatalogController.getProducts';
import { publish, MessageContext } from 'lightning/messageService';
import CART_UPDATED_CHANNEL from '@salesforce/messageChannel/CartUpdated__c';
import invokePrompt from '@salesforce/apex/PromptInvokeService.invokePrompt';
import createCart from '@salesforce/apex/CartController.createCart';
import generatePaymentLink from '@salesforce/apex/CartStripePaymentHelper.generatePaymentLink';

export default class ProductCatalog extends LightningElement {
    @wire(MessageContext) messageContext;
    @wire(getProducts) 
    loadProducts(result) {
        if (result.data) {
            this.allProducts = result.data;
            this.sortProducts();
        }
    }
    @track cartItems = [];
    @track showCart = false;
    @track sortedProducts = [];
    allProducts;
    
    // Store product quantities before adding to cart
    productQuantities = {};
    
    sortValue = 'name';
    
    get sortOptions() {
        return [
            { label: 'Name', value: 'name' },
            { label: 'Price: Low to High', value: 'price_asc' },
            { label: 'Price: High to Low', value: 'price_desc' }
        ];
    }
    
    get hasProducts() {
        return this.sortedProducts?.length > 0;
    }
    
    get products() {
        return {
            data: this.sortedProducts.map(product => ({
                ...product,
                inCart: this.cartItems.some(item => item.id === product.id),
                cartQuantity: this.cartItems.find(item => item.id === product.id)?.quantity || 1,
                cardClass: this.cartItems.some(item => item.id === product.id) ? 'product-card in-cart-card' : 'product-card',
                cartButtonClass: this.cartItems.some(item => item.id === product.id) ? 'add-cart-button in-cart' : 'add-cart-button'
            }))
        };
    }
    
    handleQuantityChange(event) {
        const productId = event.target.dataset.id;
        const quantity = parseInt(event.target.value, 10);
        if (quantity > 0) {
            this.productQuantities[productId] = quantity;
            // If product is in cart, update cart quantity
            const cartItem = this.cartItems.find(item => item.id === productId);
            if (cartItem) {
                cartItem.quantity = quantity;
                this.cartItems = [...this.cartItems];
                this.notifyCartUpdate();
            }
        }
    }
    
    handleAddToCart(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.products.data.find(p => p.id === productId);
        const quantity = this.productQuantities[productId] || 1;
        
        const existingItem = this.cartItems.find(item => item.id === productId);
        if (existingItem) {
            existingItem.quantity += quantity;
            this.cartItems = [...this.cartItems];
        } else {
            this.cartItems.push({
                ...product,
                quantity: quantity,
                formattedPrice: product.price.toFixed(2),
                get formattedSubtotal() {
                    return (this.price * this.quantity).toFixed(2);
                }
            });
        }
        
        // Reset quantity input
        this.productQuantities[productId] = 1;
        const quantityInput = this.template.querySelector(`lightning-input[data-id="${productId}"]`);
        if (quantityInput) {
            quantityInput.value = 1;
        }
        
        // Notify other components about cart update
        publish(this.messageContext, CART_UPDATED_CHANNEL, {
            cartItems: this.cartItems
        });
    }
    
    handleIncreaseQuantity(event) {
        const productId = event.currentTarget.dataset.id;
        const item = this.cartItems.find(item => item.id === productId);
        if (item) {
            item.quantity += 1;
            this.cartItems = [...this.cartItems];
            this.notifyCartUpdate();
        }
    }
    
    handleDecreaseQuantity(event) {
        const productId = event.currentTarget.dataset.id;
        const item = this.cartItems.find(item => item.id === productId);
        if (item && item.quantity > 1) {
            item.quantity -= 1;
            this.cartItems = [...this.cartItems];
            this.notifyCartUpdate();
        }
    }
    
    handleRemoveItem(event) {
        const productId = event.currentTarget.dataset.id;
        this.cartItems = this.cartItems.filter(item => item.id !== productId);
        this.notifyCartUpdate();
        
        // If cart is empty after removal, close the cart
        if (this.cartItems.length === 0) {
            this.showCart = false;
        }
    }
    
    notifyCartUpdate() {
        publish(this.messageContext, CART_UPDATED_CHANNEL, {
            cartItems: this.cartItems
        });
    }
    
    toggleCart() {
        this.showCart = !this.showCart;
    }
    
    get cartItemCount() {
        return this.cartItems.reduce((total, item) => total + item.quantity, 0);
    }
    
    get cartTotal() {
        return this.cartItems.reduce((total, item) => total + (parseFloat(item.price) * item.quantity), 0).toFixed(2);
    }
    
    handleSort(event) {
        this.sortValue = event.detail.value;
        this.sortProducts();
    }
    
    sortProducts() {
        if (!this.allProducts) return;
        
        let sortedData = [...this.allProducts];
        
        switch(this.sortValue) {
            case 'name':
                sortedData.sort((a, b) => a.name.localeCompare(b.name));
                break;
            case 'price_asc':
                sortedData.sort((a, b) => a.price - b.price);
                break;
            case 'price_desc':
                sortedData.sort((a, b) => b.price - a.price);
                break;
            default:
                // Default to name sorting
                sortedData.sort((a, b) => a.name.localeCompare(b.name));
        }
        
        this.sortedProducts = sortedData;
    }
    
    handleQuickAdd(event) {
        const productId = event.currentTarget.dataset.id;
        // Use existing add to cart logic
        this.handleAddToCart({ currentTarget: { dataset: { id: productId } } });
    }
    
    @track showInstallationModal = false;
    @track selectedProductId;
    @track userQuestion = '';
    @track selectedProduct;
    @track installationInfo = '';
    @track isLoading = false;
    @track isGuideExpanded = true;
    @track currentStep = 1;
    
    get guideResizeIcon() {
        return this.isGuideExpanded ? 'utility:minimize_window' : 'utility:expand';
    }
    
    get flowContentClass() {
        return `flow-content ${this.isGuideExpanded ? 'expanded' : 'collapsed'}`;
    }
    
    toggleGuideSize() {
        this.isGuideExpanded = !this.isGuideExpanded;
    }
    
    handleDownload() {
        console.log('this.installationInf ',this.installationInf);
        if (!this.installationInfo) return;
        
        // Create the file content
        const content = `Installation Guide for ${this.selectedProduct.name}\n\n${this.installationInfo}`;
        
        // Create a Blob with the content
        const blob = new Blob([content], { type: 'text/plain' });
        
        // Create download link
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${this.selectedProduct.name}-Installation-Guide.txt`;
        
        // Trigger download
        document.body.appendChild(link);
        link.click();
        
        // Cleanup
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
    }
    
    get flowInputVariables() {
        if (!this.selectedProductId) return null;
        
        return [{
            name: 'recordId',
            type: 'String',
            value: this.selectedProductId
        }];
    }
    
    handleInstallationGuide(event) {
        this.selectedProductId = event.currentTarget.dataset.id;
        this.selectedProduct = this.products.data.find(p => p.id === this.selectedProductId);
        this.showInstallationModal = true;
    }
    
    closeInstallationModal() {
        this.showInstallationModal = false;
        this.selectedProductId = null;
        this.selectedProduct = null;
        this.userQuestion = '';
    }
    
    get isInputEmpty() {
        return !this.userQuestion || this.userQuestion.trim().length === 0;
    }
    
    get isButtonDisabled() {
        return this.isInputEmpty || this.isLoading;
    }
    
    handleQuestionChange(event) {
        this.userQuestion = event.target.value;
    }
    
    handleKeyUp(event) {
        if (event.key === 'Enter' && !this.isInputEmpty) {
            this.handleAskQuestion();
        }
    }
    
    handleFlowStatusChange(event) {
        console.log('FLOW STATUS ',event.detail);
       
        if (event.detail.status === 'FINISHED' || event.detail.status === 'STARTED') {
             // Store the flow output
            this.installationInfo = event.detail.outputVariables.find(
                variable => variable.name === 'installationText'
            )?.value || '';
        }
    }
    
    handleAskQuestion() {
        if (this.isInputEmpty) return;
        
        this.isLoading = true;
        // Add user message to chat
        this.addMessageToChat(this.userQuestion, 'user');
        
        // Call the prompt service
        console.log('this.installationInfo in prompt call ',this.installationInfo);
        invokePrompt({ 
            userQuery: this.userQuestion, 
            installationInfo: this.installationInfo 
        })
            .then(result => {
                this.addMessageToChat(result, 'assistant');
            })
            .catch(error => {
                this.addMessageToChat('Sorry, I encountered an error processing your question. Please try again.', 'assistant');
                console.error('Error invoking prompt:', error);
            })
            .finally(() => {
                this.userQuestion = '';
                this.isLoading = false;
            });
    }
    
    addMessageToChat(text, type) {
        const chatMessages = this.template.querySelector('.chat-messages');
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${type}-message`;
        messageDiv.textContent = text;
        chatMessages.appendChild(messageDiv);
        
        // Scroll to bottom
        messageDiv.scrollIntoView({ behavior: 'smooth' });
    }
    
    connectedCallback() {
        this.handleScroll = this.handleScroll.bind(this);
        window.addEventListener('scroll', this.handleScroll);
    }
    
    renderedCallback() {
        // Detect if we're in Salesforce or Community
        const isSalesforce = document.querySelector('.desktop.container');
        const header = this.template.querySelector('.header');
        if (isSalesforce && header) {
            this.template.querySelector('.header').classList.add('salesforce-header');
        }
    }
    
    disconnectedCallback() {
        window.removeEventListener('scroll', this.handleScroll);
    }
    
    handleScroll() {
        const header = this.template.querySelector('.header');
        if (window.scrollY > 10) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
    }
    
    @track showPreviewModal = false;
    @track previewProduct;
    @track showAddressModal = false;
    
    handleQuickView(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.products.data.find(p => p.id === productId);
        this.previewProduct = product;
        this.showPreviewModal = true;
    }
    
    closePreviewModal() {
        this.showPreviewModal = false;
        this.previewProduct = null;
    }
    
    handlePreviewAddToCart() {
        this.handleAddToCart({ currentTarget: { dataset: { id: this.previewProduct.id } } });
        this.closePreviewModal();
    }
    
    handleShareProduct(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.products.data.find(p => p.id === productId);
        // Share product logic (could use navigator.share if available)
        if (navigator.share) {
            navigator.share({
                title: product.name,
                text: product.description,
                url: window.location.href
            });
        }
    }
    
    handleSaveForLater(event) {
        const productId = event.currentTarget.dataset.id;
        // Save for later logic
    }
    
    handleCheckout() {
        console.log('Checkout clicked');
        this.showAddressModal = true;
    }
    
    closeAddressModal() {
        this.showAddressModal = false;
    }
    
    copyBillingToShipping() {
        const form = this.template.querySelector('lightning-record-edit-form');
        const billingStreet = form.querySelector('[field-name="Billing_Street__c"]').value || '';
        const billingCity = form.querySelector('[field-name="Billing_City__c"]').value || '';
        const billingState = form.querySelector('[field-name="Billing_State__c"]').value || '';
        const billingPostal = form.querySelector('[field-name="Billing_PostalCode__c"]').value || '';
        const billingCountry = form.querySelector('[field-name="Billing_Country__c"]').value || '';

        // Get all shipping fields
        const shippingStreet = form.querySelector('[field-name="Shipping_Street__c"]');
        const shippingCity = form.querySelector('[field-name="Shipping_City__c"]');
        const shippingState = form.querySelector('[field-name="Shipping_State__c"]');
        const shippingPostal = form.querySelector('[field-name="Shipping_PostalCode__c"]');
        const shippingCountry = form.querySelector('[field-name="Shipping_Country__c"]');
        
        // Dispatch change events to update the fields
        if (shippingStreet) {
            shippingStreet.value = billingStreet;
            shippingStreet.dispatchEvent(new CustomEvent('change'));
        }
        if (shippingCity) {
            shippingCity.value = billingCity;
            shippingCity.dispatchEvent(new CustomEvent('change'));
        }
        if (shippingState) {
            shippingState.value = billingState;
            shippingState.dispatchEvent(new CustomEvent('change'));
        }
        if (shippingPostal) {
            shippingPostal.value = billingPostal;
            shippingPostal.dispatchEvent(new CustomEvent('change'));
        }
        if (shippingCountry) {
            shippingCountry.value = billingCountry;
            shippingCountry.dispatchEvent(new CustomEvent('change'));
        }
    }
    
    async handleAddressSubmit(event) {
        console.log('Address submit', event.detail.fields);
        event.preventDefault();
        const fields = event.detail.fields;
        
        // Create Cart record
        const cartData = {
            Status__c: 'Draft',
            Total_Amount__c: String(this.cartTotal), // Convert to string for proper handling
            Billing_Street__c: fields.Billing_Street__c,
            Billing_City__c: fields.Billing_City__c,
            Billing_State__c: fields.Billing_State__c,
            Billing_PostalCode__c: fields.Billing_PostalCode__c,
            Billing_Country__c: fields.Billing_Country__c,
            Shipping_Street__c: fields.Shipping_Street__c,
            Shipping_City__c: fields.Shipping_City__c,
            Shipping_State__c: fields.Shipping_State__c,
            Shipping_PostalCode__c: fields.Shipping_PostalCode__c,
            Shipping_Country__c: fields.Shipping_Country__c,
            Contact_Email__c: fields.Contact_Email__c,
            Contact_Phone__c: fields.Contact_Phone__c
        };

        try {
            // Create cart and cart items
            const result = await createCart({ 
                cartData: cartData,
                cartItems: this.cartItems.map(item => ({
                    id: item.id,
                    quantity: item.quantity,
                    price: item.price
                }))
            });
            
            console.log('Cart created:', result);
            
            // Generate payment link
            const paymentLink = await generatePaymentLink({ cartId: result.cartId });
            
            console.log('Payment link generated:', paymentLink);
            
            // Redirect to payment link
            window.location.href = paymentLink;
            
        } catch (error) {
            console.error('Error in checkout:', error);
            this.showToast('Error', error.message, 'error');
        }
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
    
    nextStep() {
        if (this.currentStep < 3) {
            this.template.querySelector(`[data-step="${this.currentStep}"]`).classList.add('hidden');
            this.currentStep += 1;
            this.template.querySelector(`[data-step="${this.currentStep}"]`).classList.remove('hidden');
            
            // Update progress indicator
            const steps = this.template.querySelectorAll('.progress-step');
            steps.forEach((step, index) => {
                if (index + 1 <= this.currentStep) {
                    step.classList.add('active');
                } else {
                    step.classList.remove('active');
                }
            });
        }
    }
    
    previousStep() {
        if (this.currentStep > 1) {
            this.template.querySelector(`[data-step="${this.currentStep}"]`).classList.add('hidden');
            this.currentStep -= 1;
            this.template.querySelector(`[data-step="${this.currentStep}"]`).classList.remove('hidden');
            
            // Update progress indicator
            const steps = this.template.querySelectorAll('.progress-step');
            steps.forEach((step, index) => {
                if (index + 1 <= this.currentStep) {
                    step.classList.add('active');
                } else {
                    step.classList.remove('active');
                }
            });
        }
    }
} 