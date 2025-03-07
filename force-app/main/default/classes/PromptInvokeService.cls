public without sharing class PromptInvokeService {

   @AuraEnabled
   public static String invokePrompt(String userQuery , String installationInfo){
       Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
       ConnectApi.WrappedValue userQueryValue = new ConnectApi.WrappedValue();
       userQueryValue.value = userQuery;
       ConnectApi.WrappedValue installationInfoValue = new ConnectApi.WrappedValue();
       installationInfoValue.value = installationInfo;
       
       inputParams.put('Input:userQuery',userQueryValue);
       inputParams.put('Input:installationInfo',installationInfoValue);
       system.debug('inputParams >> '+inputParams);
       return generateResponseFromPromptTemplate('0hfgK000000MJ0nQAG',inputParams);
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