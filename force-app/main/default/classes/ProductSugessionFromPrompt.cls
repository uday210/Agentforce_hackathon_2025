public without sharing class ProductSugessionFromPrompt {
 @AuraEnabled
   public static String invokePrompt(String workOrderId ){
       Map<String, String> relatedEntityRecordIdMap = new Map<String, String>();
	   relatedEntityRecordIdMap.put('id',workOrderId);
       
       Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
       ConnectApi.WrappedValue workOrderValue = new ConnectApi.WrappedValue();
       workOrderValue.value = relatedEntityRecordIdMap;//[SELECT Id,Case.Id,Case.Subject,Case.Description FROM WorkOrder WHERE Id=:workOrderId];
       
       inputParams.put('Input:CurrentWorkOrder',workOrderValue);
       system.debug('inputParams >> '+inputParams);
       String promptTemplateId = [select id,developerName,Prompt_id__c from Prompt_Templates__mdt WHERE developerName='Product_suggestion' LIMIT 1].Prompt_id__c;
       //0hfgK000000MggXQAS
       return generateResponseFromPromptTemplate(promptTemplateId,inputParams);
   }
   public static String generateResponseFromPromptTemplate(
        String promptTemplateDeveloperName,
        Map<String, ConnectApi.WrappedValue> inputParams
    ) {
        // Create input
        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';

        // Set additional values
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;

        try {
            // Call the service
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                promptTemplateDeveloperName,
                executeTemplateInput
            );
            //system.debug('generationsOutput :: '+generationsOutput);
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            return response.text;
            
        } catch (Exception e) {
            System.debug(e.getMessage());
            throw e;
        }
    }
}