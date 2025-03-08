public without sharing class ProductsList {
//CapabilityType='PromptTemplateTye://einstein_gpt__Product_suggestion'
    @InvocableMethod
    public static List<Response> getProductsListAsString(List<Request> requests) {
        String productsString = '';
        for(product2 eachProduct : [SELECT Id,Name,Family FROM Product2 WHERE Family='Service' ]){
            Map<String,String> eachProducteDetails = new Map<String,String>{
                'ProductId'=>eachProduct.Id,
                'ProductFamily'=>eachProduct.Family,
                'Productname'=> eachProduct.name
            };
            productsString +=  JSON.serialize(eachProducteDetails);
            productsString +=  '----';
        }
        Response resp = new Response();
        resp.prompt = productsString;
        return new List<Response>{resp};
    }
    
       // Type and API Name of all variables must match the template
    public class Request {
        @InvocableVariable(required=false)
        public string workorderDetails;
    }
    
    public class Response {
        @InvocableVariable
        public String Prompt;
    }
}