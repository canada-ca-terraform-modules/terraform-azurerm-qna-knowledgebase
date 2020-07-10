# Terraform azurerm-chatbot-app

## Introduction

This module deploys a qna maker knowledgebase, azure service congnative account, service to host it, azure search service, app service plan, and application insights for monitoring.
Note you must call this module for each language you wish to deploy and only one language is allowed per service.

This module is compatible with azurerm v2.x

## Security Controls
* TBD

## Dependancies

* None


## Usage

```terraform
module "ChatbotKBService-EN" {
  source               = "./modules/qnaKBService"
  name                 = var.chatbotName
  location             = azurerm_resource_group.ChatbotSVC-rg.location
  resourceGroupName    = azurerm_resource_group.ChatbotSVC-rg.name
  prefix               = local.prefix
  KBFileName           = var.englishKBFileName
  KBLanguageCode       = var.englishKBLanguageCode
  qna_tier             = var.qna_tier
  qna_size             = var.qna_size
  search_sku           = var.search_sku
  account_sku          = var.account_sku
  tags                 = var.tags
}

module "ChatbotKBService-FR" {
  source               = "./modules/qnaKBService"
  name                 = var.chatbotName
  location             = azurerm_resource_group.ChatbotSVC-rg.location
  resourceGroupName    = azurerm_resource_group.ChatbotSVC-rg.name
  prefix               = local.prefix
  KBFileName           = var.frenchKBFileName
  KBLanguageCode       = var.frenchKBLanguageCode
  qna_tier             = var.qna_tier
  qna_size             = var.qna_size
  search_sku           = var.search_sku
  account_sku          = var.account_sku
  tags                 = var.tags
}

output "English_Knowledgebase_ID" {
  value = "${module.ChatbotKBService-EN.KBID}"
}

output "French_Knowledgebase_ID" {
  value = "${module.ChatbotKBService-FR.KBID}"
}
```

## Variables Values

| Name                                    | Type   | Required | Notes                                                                                                       | 
| --------------------------------------- | ------ | -------- |------------------------------------------------------------------------------------------------------------ |
| prefix                                  | string | yes      | The prefix to add to the name for the knowledgebase |
| tags                                    | object | no       | Object containing a tag values - [tags pairs](#tag-object) |
| location                                | string | yes      | The location to deploy to.  canadacentral, canadaeast |
| KBFileName                              | string | yes      | The file name of the knowledgebase template to use. |
| KBLanguageCode                          | string | yes      | The language code to use when naming the KB (EN, FR). |
| resourceGroupName                      | string | yes       | The name of the resource group to put the knowledgebase components into. |
| qna_tier                               | string | no       | The tier for the chatbot application service plan.  Free, Shared, Standard.  Note only one free one is allowed. Defaults to Free |
| qna_size                                | string | no       | The size for the chatbot qna service.  F1, D1, S1.  Note only one free one is allowed.  Defaults to F1. |
| search_sku                              | string | no        | The sku to use for the azure search service.  Defaults to standard. |
| account_sku                             | string | no        | The sku to use for the azure congative account.  Defaults to S0 |

### tag object

Example tag variable:

```hcl
tags = {
  "tag1name" = "somevalue"
  "tag2name" = "someothervalue"
  .
  .
  .
  "tagXname" = "some other value"
}
```


## History

| Date     | Release    | Change                                                                                                |
| -------- | ---------- | ----------------------------------------------------------------------------------------------------- |
| 20200708 | 20200708.1 | 1st commit                                                                                            |
| 20200710 | 20200710.1 | Fixed endpoints                                                                                       |
