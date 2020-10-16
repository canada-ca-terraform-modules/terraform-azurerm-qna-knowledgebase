
resource "random_uuid" "uuid" {
}

resource "null_resource" "Chatbot-kb" {
  for_each = var.knowledgebaseList.knowledgebase
    provisioner "local-exec" {
        command = <<EOT
          $tryCount = 10
          Do{
            $failed = $false;
            
            Try{
               Write-Host "Trying to create the knowledgebase"
               $data = '${file(each.value)}'
               $data = [System.Text.Encoding]::UTF8.GetBytes($data)
               $createResultJson = Invoke-WebRequest -Uri '${azurerm_cognitive_account.Chatbot-svc.endpoint}qnamaker/v4.0/knowledgebases/create'  -Body $data -Headers @{'Content-Type'='application/json'; 'charset'='utf-8';'Ocp-Apim-Subscription-Key'= '${azurerm_cognitive_account.Chatbot-svc.primary_access_key}'} -Method Post
               
               $createResult = $createResultJson | ConvertFrom-Json
               $oppid = $createResult.operationId 
               Write-Host $createResult
               Write-Host "OperationID: $oppid"
               
            $endpoint = '${azurerm_cognitive_account.Chatbot-svc.endpoint}qnamaker/v4.0/operations/'
            $endpoint = $endpoint + $oppid
            Do{
               Write-Host "Trying to get the kb id"
               $resultJson = Invoke-WebRequest -Uri $endpoint -Headers @{'Content-Type'='application/json'; 'charset'='utf-8';'Ocp-Apim-Subscription-Key'= '${azurerm_cognitive_account.Chatbot-svc.primary_access_key}'} -Method Get
               Write-Host $resultJson
               $oppResult = $resultJson | ConvertFrom-Json
               
               if($oppResult.resourceLocation -eq $null -And $oppResult.operationState -ne "Failed")
               {
                 Start-Sleep -s 300
               }

            } While ($oppResult.resourceLocation -eq $null -And $oppResult.operationState -ne "Failed" )
            $resourceLocation =  $oppResult.resourceLocation
            Write-Host "Knowledgebase created: $resourceLocation"
            try
            {
              $oppResult.resourceLocation | Out-File -Encoding "UTF8" -FilePath "./${"./tmp/${var.prefix}.${each.value}.${random_uuid.uuid.result}"}" 
            }
            catch
            {
               $failed = $true 
               Write-Host $_
               $trycount=0
            }
                   

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
        interpreter = ["pwsh", "-Command"] 
      
    }
    provisioner "local-exec" {
      when    = destroy
      command = "Remove-Item ./${path.module}/tmp/*.* -Force"
      interpreter = ["pwsh", "-Command"] 
    }
    triggers = {
      "before" = "${azurerm_cognitive_account.Chatbot-svc.id}"
 }
}

resource "null_resource" "Chatbot-kb-result-if-missing" {
  for_each = var.knowledgebaseList.knowledgebase
  depends_on = [null_resource.Chatbot-kb]
  triggers = {
    result     = fileexists("./tmp/${var.prefix}.${each.value}.${random_uuid.uuid.result}") ? replace(chomp(file("./tmp/${var.prefix}.${each.value}.${random_uuid.uuid.result}")),"\ufeff","") : ""
    
  }

  lifecycle {
    ignore_changes = [
      triggers
    ]
  }
}

resource "null_resource" "Chatbot-kb-result" {
  for_each = var.knowledgebaseList.knowledgebase
  depends_on = [null_resource.Chatbot-kb-result-if-missing]
  triggers = {
    id = null_resource.Chatbot-kb.id
    result     = fileexists("./tmp/${var.prefix}.${each.value}.${random_uuid.uuid.result}") ? replace(chomp(file("./tmp/${var.prefix}.${each.value}.${random_uuid.uuid.result}")),"\ufeff","") :  lookup(null_resource.Chatbot-kb-result-if-missing[each.value].triggers, "result", "")
    
  } 
}

 resource "null_resource" "Chatbot-kb-publish" {
    for_each = var.knowledgebaseList.knowledgebase
    provisioner "local-exec" {
        command = <<EOT
            Write-Host "Publishing knowledgebase"
            If("${null_resource.Chatbot-kb-result[each.key].triggers["result"]}" -ne "")
            {
               $publishResult = Invoke-WebRequest -Uri "${azurerm_cognitive_account.Chatbot-svc.endpoint}qnamaker/v4.0/${null_resource.Chatbot-kb-result[each.key].triggers["result"]}" -Headers @{'Content-Type'='application/json'; 'charset'='utf-8';'Ocp-Apim-Subscription-Key'= '${azurerm_cognitive_account.Chatbot-svc.primary_access_key}'} -Method Post
            }
            
        EOT
        interpreter = ["pwsh", "-Command"] 
      
    }
    depends_on = [null_resource.Chatbot-kb-result, null_resource.Chatbot-kb]
  }

  resource "null_resource" "Chatbot-kb-GetSubKey" {
    for_each = var.knowledgebaseList.knowledgebase
    provisioner "local-exec" {
        command = <<EOT
              $endpoint = '${azurerm_cognitive_account.Chatbot-svc.endpoint}qnamaker/v4.0/endpointkeys/'
               $resultJson = Invoke-WebRequest -Uri $endpoint -Headers @{'Content-Type'='application/json'; 'charset'='utf-8';'Ocp-Apim-Subscription-Key'= '${azurerm_cognitive_account.Chatbot-svc.primary_access_key}'} -Method Get
               Write-Host $resultJson
               $result = $resultJson | ConvertFrom-Json
               
            $resourceLocation =  $oppResult.resourceLocation
            $result.primaryEndpointKey | Out-File -Encoding "UTF8" -FilePath "./tmp/${var.prefix}.${each.value}-key.${random_uuid.uuid.result}"
                   
          
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
    for_each = var.knowledgebaseList.knowledgebase
  depends_on = [null_resource.Chatbot-kb-GetSubKey]
  triggers = {
    result     = fileexists("./tmp/${var.prefix}.${each.value}-key.${random_uuid.uuid.result}") ? replace(chomp(file("./tmp/${var.prefix}.${each.value}-key.${random_uuid.uuid.result}")),"\ufeff","") : ""
    
  }

  lifecycle {
    ignore_changes = [
      triggers
    ]
  }
}

resource "null_resource" "Chatbot-kb-GetSubKey-result" {
  for_each = var.knowledgebaseList.knowledgebase
  depends_on = [null_resource.Chatbot-kb-GetSubKey-result-if-missing]
  triggers = {
    id = null_resource.Chatbot-kb.id
    result     = fileexists("./tmp/${var.prefix}.${each.value}-key.${random_uuid.uuid.result}") ? replace(chomp(file("./tmp/${var.prefix}.${each.value}-key.${random_uuid.uuid.result}")),"\ufeff","") :  lookup(null_resource.Chatbot-kb-GetSubKey-result-if-missing.triggers, "result", "")
    
  } 
}


output "KBID" {
  for_each = var.knowledgebaseList.knowledgebase
  value = "${null_resource.Chatbot-kb-result[each.key].triggers["result"]}"
}

output "key" {
  for_each = var.knowledgebaseList.knowledgebase
  value = "${null_resource.Chatbot-kb-GetSubKey-result[each.key].triggers["result"]}"
}

