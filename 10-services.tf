
//Removed plan per langauge
resource "azurerm_app_service_plan" "Chatbot-svcplan" {
  count               = var.plan_id == "" ? 1 : 0
  name                = "${var.prefix}-svcplan"
  location            = var.location
  resource_group_name = var.resourceGroupName
  kind                = var.plan_kind == "" ? "Windows" : var.plan_kind
  reserved            = var.plan_reserved
  sku {
    //Only get one Free/F1.  Shared/Free need use_32_bit_worker_process = true in the application service 
    tier = var.qna_tier
    size = var.qna_size
  }
  tags = var.tags
}

resource "azurerm_application_insights" "Chatbot-svc-ai" {
  name                = "${var.prefix}-svc-appi"
  location            = var.location
  resource_group_name = var.resourceGroupName
  application_type    = "web"
  tags                = var.tags
}

resource "random_string" "random" {
  length  = 12
  special = false
  lower   = true
  upper   = false
}

resource "azurerm_search_service" "Chatbot-search" {
  count               = var.search_service == "" ? 1 : 0
  name                = "${lower(replace(var.prefix, "/-*_*/", ""))}svc${random_string.random.result}-ss"
  location            = var.location
  resource_group_name = var.resourceGroupName
  sku                 = var.search_sku
  tags                = var.tags
}

//Does not like underscores in the name
resource "azurerm_app_service" "Chatbot-svc" {
  name                = "${var.prefix}-svc"
  location            = var.location
  resource_group_name = var.resourceGroupName
  app_service_plan_id = var.plan_id == "" ? azurerm_app_service_plan.Chatbot-svcplan[0].id : var.plan_id
  https_only          = true
  site_config {
    dotnet_framework_version = "v4.0"
    cors {
      allowed_origins = ["*"]
    }
    use_32_bit_worker_process = var.qna_tier == "Standard" ? false : true //True for free and shared tiers.  False for Standard
  }

  app_settings = {
    "AzureSearchName" = var.search_service == "" ? azurerm_search_service.Chatbot-search[0].name : var.search_service
    "AzureSearchAdminKey" : var.search_service_key == "" ? azurerm_search_service.Chatbot-search[0].primary_key : var.search_service_key
    "UserAppInsightsKey" : azurerm_application_insights.Chatbot-svc-ai.instrumentation_key
    "UserAppInsightsName" : azurerm_application_insights.Chatbot-svc-ai.name
    "UserAppInsightsAppId" : azurerm_application_insights.Chatbot-svc-ai.app_id
    "PrimaryEndpointKey" : "${var.prefix}-svc-PrimaryEndpointKey"
    "SecondaryEndpointKey" : "${var.prefix}-svc-SecondaryEndpointKey"
    "DefaultAnswer" : "No good match found in KB.",
    "QNAMAKER_EXTENSION_VERSION" : "latest"
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

  name                 = "${var.prefix}-svc"
  location             = var.cognitiveServicesLocation
  resource_group_name  = var.resourceGroupName
  kind                 = "QnAMaker"
  sku_name             = var.account_sku
  qna_runtime_endpoint = "https://${azurerm_app_service.Chatbot-svc.default_site_hostname}"
  depends_on = [
    azurerm_app_service.Chatbot-svc

  ]
  tags = var.tags
}

output "app_srv" {
  value = azurerm_app_service.Chatbot-svc
}

output "plan_id" {
  value = var.plan_id == "" ? azurerm_app_service_plan.Chatbot-svcplan[0].id : var.plan_id

}

output "cognitive_account" {
  value = azurerm_cognitive_account.Chatbot-svc
}

output "search_service" {
  value = azurerm_search_service.Chatbot-search
}
