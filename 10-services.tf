//Removed plan per langauge
resource "azurerm_app_service_plan" "Chatbot-svcplan" {
  count = var.plan_id == "" ? 1 : 0
  name                = "${var.prefix}-svcplan"
  location            = var.location
  resource_group_name = var.resourceGroupName
  kind = var.plan_kind == "" ? "Windows" : var.plan_kind
  reserved = var.plan_reserved
  sku {
    //Only get one Free/F1.  Shared/Free need use_32_bit_worker_process = true in the application service 
    tier = var.qna_tier
    size = var.qna_size
    
  }
  tags = var.tags
}

resource "azurerm_application_insights" "Chatbot-svc-ai" {
  for_each = var.knowledgebaseList
  name                = "${var.prefix}${each.value.languageCode}-svc-appi"
  location            = var.location
  resource_group_name = var.resourceGroupName
  application_type    = "web"
  tags = var.tags
}

resource "random_string" "random" {
  length = 12
  special = false
  lower = true
  upper = false
}

resource "azurerm_search_service" "Chatbot-search" {
  for_each = var.knowledgebaseList
  name                = "${lower(replace(var.prefix,"/-*_*/",""))}${lower(each.value.languageCode)}svc${random_string.random.result}-ss"
  location            = var.location
  resource_group_name = var.resourceGroupName
  sku                 = var.search_sku
  tags = var.tags
}

//Does not like underscores in the name
resource "azurerm_app_service" "Chatbot-svc" {
  for_each = var.knowledgebaseList
  name                = "${var.prefix}${each.value.languageCode}-svc"
  location            = var.location
  resource_group_name = var.resourceGroupName
  app_service_plan_id = var.plan_id == "" ? azurerm_app_service_plan.Chatbot-svcplan[0].id : var.plan_id

  site_config {
    dotnet_framework_version = "v4.0"
    cors {
      allowed_origins     = ["*"]
    }
    use_32_bit_worker_process = var.qna_tier == "Standard" ? false : true  //True for free and shared tiers.  False for Standard
  }

  app_settings = {
     "AzureSearchName" = azurerm_search_service.Chatbot-search[each.key].name
     "AzureSearchAdminKey": azurerm_search_service.Chatbot-search[each.key].primary_key
     "UserAppInsightsKey": azurerm_application_insights.Chatbot-svc-ai[each.key].instrumentation_key
     "UserAppInsightsName": azurerm_application_insights.Chatbot-svc-ai[each.key].name
     "UserAppInsightsAppId": azurerm_application_insights.Chatbot-svc-ai[each.key].app_id
     "PrimaryEndpointKey": "${var.prefix}${each.value.languageCode}-svc-PrimaryEndpointKey"
     "SecondaryEndpointKey": "${var.prefix}${each.value.languageCode}-svc-SecondaryEndpointKey"
     "DefaultAnswer": "No good match found in KB.",
     "QNAMAKER_EXTENSION_VERSION": "latest"
  }
  
  depends_on = [
      azurerm_application_insights.Chatbot-svc-ai,
      azurerm_app_service_plan.Chatbot-svcplan,
      azurerm_search_service.Chatbot-search
  ]
  tags = var.tags
}

//Looks like ARM has the ability to specify a custom domain but not here so it will be https://westus.api.cognitive.microsoft.com/qnamaker/v4.0
//Taint does not tear this down but destroying the services will
resource "azurerm_cognitive_account" "Chatbot-svc" {
  for_each = var.knowledgebaseList
  name                = "${var.prefix}${each.value.languageCode}-svc"
  location            = var.cognitiveServicesLocation 
  resource_group_name = var.resourceGroupName
  kind                = "QnAMaker"
  sku_name = var.account_sku
  qna_runtime_endpoint = "https://${azurerm_app_service.Chatbot-svc.default_site_hostname}"
  depends_on = [
      azurerm_app_service.Chatbot-svc
  ]
  tags = var.tags
}

output "endpoint" {
  value = azurerm_app_service.Chatbot-svc.default_site_hostname
}

output "plan_id" {
  value = var.plan_id == "" ? azurerm_app_service_plan.Chatbot-svcplan[0].id : var.plan_id
}