
locals {
  filepath = "${path.module}/tmp/${var.prefix}${var.KBLanguageCode}.${random_uuid.uuid.result}"
  filepath-key = "${path.module}/tmp/${var.prefix}${var.KBLanguageCode}-key.${random_uuid.uuid.result}"
}

resource "azurerm_app_service_plan" "Chatbot-svcplan" {
  count = var.plan_id=="" ? : 1 : 0
  name                = "${var.prefix}${var.KBLanguageCode}-svcplan"
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
  name                = "${var.prefix}${var.KBLanguageCode}-svc-appi"
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
  name                = "${lower(replace(var.prefix,"/-*_*/",""))}${lower(var.KBLanguageCode)}svc${random_string.random.result}-ss"
  location            = var.location
  resource_group_name = var.resourceGroupName
  sku                 = var.search_sku
  tags = var.tags
}

//Does not like underscores in the name
resource "azurerm_app_service" "Chatbot-svc" {
  name                = "${var.prefix}${var.KBLanguageCode}-svc"
  location            = var.location
  resource_group_name = var.resourceGroupName
  app_service_plan_id = var.plan_id == "" ? azurerm_app_service_plan.Chatbot-svcplan.id : var.plan_id

  site_config {
    dotnet_framework_version = "v4.0"
    cors {
      allowed_origins     = ["*"]
    }
    use_32_bit_worker_process = var.qna_tier == "Standard" ? false : true  //True for free and shared tiers.  False for Standard
  }

  app_settings = {
     "AzureSearchName" = azurerm_search_service.Chatbot-search.name
     "AzureSearchAdminKey": azurerm_search_service.Chatbot-search.primary_key
     "UserAppInsightsKey": azurerm_application_insights.Chatbot-svc-ai.instrumentation_key
     "UserAppInsightsName": azurerm_application_insights.Chatbot-svc-ai.name
     "UserAppInsightsAppId": azurerm_application_insights.Chatbot-svc-ai.app_id
     "PrimaryEndpointKey": "${var.prefix}${var.KBLanguageCode}-svc-PrimaryEndpointKey"
     "SecondaryEndpointKey": "${var.prefix}${var.KBLanguageCode}-svc-SecondaryEndpointKey"
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
  name                = "${var.prefix}${var.KBLanguageCode}-svc"
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

resource "random_uuid" "uuid" {
}

  resource "null_resource" "Chatbot-kb" {
    provisioner "local-exec" {
        command = <<EOT
          $tryCount = 10
          Do{
            $failed = $false;
            
            Try{
               $data = '${file(var.KBFileName)}'
               $data = [System.Text.Encoding]::UTF8.GetBytes($data)
               $createResultJson = Invoke-WebRequest -Uri '${azurerm_cognitive_account.Chatbot-svc.endpoint}qnamaker/v4.0/knowledgebases/create'  -Body $data -Headers @{'Content-Type'='application/json'; 'charset'='utf-8';'Ocp-Apim-Subscription-Key'= '${azurerm_cognitive_account.Chatbot-svc.primary_access_key}'} -Method Post
               
               $createResult = $createResultJson | ConvertFrom-Json
               $oppid = $createResult.operationId 
               Write-Host $createResult
               Write-Host "OperationID: $oppid"
               
            $endpoint = '${azurerm_cognitive_account.Chatbot-svc.endpoint}qnamaker/v4.0/operations/'
            $endpoint = $endpoint + $oppid
            Do{
               $resultJson = Invoke-WebRequest -Uri $endpoint -Headers @{'Content-Type'='application/json'; 'charset'='utf-8';'Ocp-Apim-Subscription-Key'= '${azurerm_cognitive_account.Chatbot-svc.primary_access_key}'} -Method Get
               Write-Host $resultJson
               $oppResult = $resultJson | ConvertFrom-Json
               
               Start-Sleep -s 300

            } While ($oppResult.resourceLocation -eq $null -And $oppResult.operationState -ne "Failed" )
            $resourceLocation =  $oppResult.resourceLocation
            Write-Host "Knowledgebase created: $resourceLocation"
            $oppResult.resourceLocation | Out-File -Encoding "UTF8" -FilePath "./${local.filepath}" 
                   

            } 
            catch { 
              $failed = $true 
              
              Write-Host $_
              Write-Host "Service endpoint may not be ready trying again in 5 minutes.  Try $tryCount of 10"
              
              $trycount--
              Start-Sleep -s 300
            }                       
          } While ($failed -eq $true -And $tryCount -gt 0)
          
          If($trycount -eq 0)
          {
            Write-Host "Error: KB could not be created.  Try again later."
          }        
          
        EOT
        interpreter = ["PowerShell", "-Command"] 
      
    }
    provisioner "local-exec" {
      when    = destroy
      command = "Remove-Item ./${path.module}/tmp/*.* -Force"
      interpreter = ["PowerShell", "-Command"] 
    }
    triggers = {
      "before" = "${azurerm_cognitive_account.Chatbot-svc.id}"
 }
  }

resource "null_resource" "Chatbot-kb-result-if-missing" {
  depends_on = [null_resource.Chatbot-kb]
  triggers = {
    result     = fileexists(local.filepath) ? replace(chomp(file(local.filepath)),"\ufeff","") : ""
    
  }

  lifecycle {
    ignore_changes = [
      triggers
    ]
  }
}

resource "null_resource" "Chatbot-kb-result" {
  depends_on = [null_resource.Chatbot-kb-result-if-missing]
  triggers = {
    id = null_resource.Chatbot-kb.id
    result     = fileexists(local.filepath) ? replace(chomp(file(local.filepath)),"\ufeff","") :  lookup(null_resource.Chatbot-kb-result-if-missing.triggers, "result", "")
    
  } 
}

 resource "null_resource" "Chatbot-kb-publish" {
    provisioner "local-exec" {
        command = <<EOT
            Write-Host "Publishing knowledgebase"
            If("${null_resource.Chatbot-kb-result.triggers["result"]}" -ne "")
            {
               $publishResult = Invoke-WebRequest -Uri "${azurerm_cognitive_account.Chatbot-svc.endpoint}qnamaker/v4.0/${null_resource.Chatbot-kb-result.triggers["result"]}" -Headers @{'Content-Type'='application/json'; 'charset'='utf-8';'Ocp-Apim-Subscription-Key'= '${azurerm_cognitive_account.Chatbot-svc.primary_access_key}'} -Method Post
            }
            
        EOT
        interpreter = ["PowerShell", "-Command"] 
      
    }
    depends_on = [null_resource.Chatbot-kb-result, null_resource.Chatbot-kb]
  }

  resource "null_resource" "Chatbot-kb-GetSubKey" {
    provisioner "local-exec" {
        command = <<EOT
              $endpoint = '${azurerm_cognitive_account.Chatbot-svc.endpoint}qnamaker/v4.0/endpointkeys/'
               $resultJson = Invoke-WebRequest -Uri $endpoint -Headers @{'Content-Type'='application/json'; 'charset'='utf-8';'Ocp-Apim-Subscription-Key'= '${azurerm_cognitive_account.Chatbot-svc.primary_access_key}'} -Method Get
               Write-Host $resultJson
               $result = $resultJson | ConvertFrom-Json
               
            $resourceLocation =  $oppResult.resourceLocation
            $result.primaryEndpointKey | Out-File -Encoding "UTF8" -FilePath "./${local.filepath-key}" 
                   

          
        EOT
        interpreter = ["PowerShell", "-Command"] 
      
    }
    depends_on = [null_resource.Chatbot-kb-publish]
    provisioner "local-exec" {
      when    = destroy
      command = "Remove-Item ./${path.module}/tmp/*-key.* -Force"
      interpreter = ["PowerShell", "-Command"] 
    }
    triggers = {
      "before" = "${azurerm_cognitive_account.Chatbot-svc.id}"
 }
  }

  resource "null_resource" "Chatbot-kb-GetSubKey-result-if-missing" {
  depends_on = [null_resource.Chatbot-kb-GetSubKey]
  triggers = {
    result     = fileexists(local.filepath-key) ? replace(chomp(file(local.filepath-key)),"\ufeff","") : ""
    
  }

  lifecycle {
    ignore_changes = [
      triggers
    ]
  }
}

resource "null_resource" "Chatbot-kb-GetSubKey-result" {
  depends_on = [null_resource.Chatbot-kb-GetSubKey-result-if-missing]
  triggers = {
    id = null_resource.Chatbot-kb.id
    result     = fileexists(local.filepath-key) ? replace(chomp(file(local.filepath-key)),"\ufeff","") :  lookup(null_resource.Chatbot-kb-GetSubKey-result-if-missing.triggers, "result", "")
    
  } 
}


output "KBID" {
  value = "${null_resource.Chatbot-kb-result.triggers["result"]}"
}

output "endpoint" {
  value = azurerm_app_service.Chatbot-svc.default_site_hostname
}

output "key" {
  value = "${null_resource.Chatbot-kb-GetSubKey-result.triggers["result"]}"
}

output "plan_id" {
  value = var.plan_id == "" ? azurerm_app_service_plan.Chatbot-svcplan.id : var.plan_id
}