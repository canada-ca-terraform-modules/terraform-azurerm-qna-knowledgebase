# Terraform azurerm-qna-knowledgebase

## Introduction

This module deploys a qna maker knowledgebase, azure service congnative account, service to host it, azure search service, app service plan, and application insights for monitoring.
Note you must call this module for each language you wish to deploy and only one language is allowed per service.

This module is compatible with azurerm v2.x and assumes deploying from a Linux VM.

## Docker Setup
If you are using the Microsoft CAF framework with rover you can add the following to your Dockerfile:
```
FROM sscspccloudnuage/rover:2009.0812
RUN curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo && sudo yum install -y powershell
```

## Security Controls
* TBD

## Dependancies

* None


## Usage

```terraform
locals {
  deployList = {
    for x in var.knowledgebaseList :
    "${x.languageCode}" => x if lookup(x, "deploy", true) != false
  }
}

module "ScSc-CIO-Chatbot-KB" {
  for_each                  = local.deployList
  source                    = "github.com/canada-ca-terraform-modules/terraform-azurerm-qna-knowledgebase?ref=202010116.dev"
  location                  = local.resource_groups_L2.Project.location
  cognitiveServicesLocation = var.cognitiveServicesLocation
  resourceGroupName         = local.resource_groups_L2.Project.name
  prefix                    = "${local.prefix}-${each.key}"
  knowledgebaseList         = each.value.knowledgebaseLocations
  qna_tier                  = var.qna_tier
  qna_size                  = var.qna_size
  search_sku                = var.search_sku
  account_sku               = var.account_sku
  tags                      = var.tags
}

output "English_Knowledgebase_ID" {
  value = "${module.ScSc-CIO-Chatbot-KB[0].KBList.triggers["result"]}"
}

output "French_Knowledgebase_ID" {
  value = "${module.ScSc-CIO-Chatbot-KB[1].KBList.triggers["result"]}"
}

```

## Variables Values

| Name                                    | Type   | Required | Notes                                                                                                       | 
| --------------------------------------- | ------ | -------- |------------------------------------------------------------------------------------------------------------ |
| prefix                                  | string | yes      | The prefix to add to the name for the knowledgebase |
| tags                                    | object | no       | Object containing a tag values - [tags pairs](#tag-object) |
| location                                | string | yes      | The location to deploy to.  canadacentral, canadaeast |
| knowledgebaseList                              | object | yes      | A List of knowledgebase locations to add.  Knowledge base files must exist in the project - [knowledgebase List](#knowledgebase-list) |
| resourceGroupName                      | string | yes       | The name of the resource group to put the knowledgebase components into. |
| qna_tier                               | string | no       | The tier for the chatbot application service plan.  Free, Shared, Standard.  Note only one free one is allowed. Defaults to Free |
| qna_size                                | string | no       | The size for the chatbot qna service.  F1, D1, S1.  Note only one free one is allowed.  Defaults to F1. |
| search_sku                              | string | no        | The sku to use for the azure search service.  Defaults to standard. |
| account_sku                             | string | no        | The sku to use for the azure congative account.  Defaults to S0 |
| plan_id                             | string | no        | The service plan to use.  If left out it will create one |
| plan_reserved                             | string | no        | If the service plan is reserved.  Defaults to false.  Must be true for Linux plans. |
| plan_kind                             | string | no        | The kind of the App Service Plan to create. Possible values are Windows (also available as App), Linux, elastic (for Premium Consumption) and FunctionApp (for a Consumption Plan). Defaults to Windows. Changing this forces a new resource to be created. |

### knowledgebase-list
Example of knowledgebases in each language:

```hcl
knowledgebaseList = [
   {
     languageCode = "EN",
     deploy = true
     knowledgebaseLocations = {
       ScSc-CIO-Chatbot-Chit-Chaty-EN-KB = "knowledgebases/ScSc-CIO-Chatbot-Chit-Chaty-EN-KB.json",
       ScSc-CIO-Chatbot-Digital-Lounge-EN-KB = "knowledgebases/ScSc-CIO-Chatbot-Digital-Lounge-EN-KB.json",
       ScSc-CIO-Chatbot-Sample-EN-KB = "knowledgebases/ScSc-CIO-Chatbot-Sample-EN-KB.json",
       ScSc-CIO-Chatbot-Student-EN-KB= "knowledgebases/ScSc-CIO-Chatbot-Student-EN-KB.json"
     },
   },
   {
      languageCode = "FR"
      deploy = true
      knowledgebaseLocations = {
        ScSc-CIO-Chatbot-Chit-Chaty-FR-KB = "knowledgebases/ScSc-CIO-Chatbot-Chit-Chaty-FR-KB.json",
        ScSc-CIO-Chatbot-Digital-Lounge-FR-KB = "knowledgebases/ScSc-CIO-Chatbot-Digital-Lounge-FR-KB.json",
        ScSc-CIO-Chatbot-Sample-FR-KB = "knowledgebases/ScSc-CIO-Chatbot-Sample-FR-KB.json",
        ScSc-CIO-Chatbot-Student-FR-KB = "knowledgebases/ScSc-CIO-Chatbot-Student-FR-KB.json"
      }
   }
]
```

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
| 20200710 | 20200710.2 | Fixed typo                                                                                            |
| 20200715 | 20200710.1 | Added variable for cognitive services location                        |
| 20201014 | 20201014.1 | Allowing for passing in a application service plan_id 
                          Added plan_reserved.  Defaults to false.  Linux plans must be true.|
