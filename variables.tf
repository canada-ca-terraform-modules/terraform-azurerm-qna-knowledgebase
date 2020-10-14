

variable "tags" {}
variable "prefix" {}

variable "KBFileName" {
  description = "The file name of the knowledgebase template to use."
}

variable "KBLanguageCode" {
  description = "The language code to use when naming the KB (EN, FR)."
}

variable "resourceGroupName" {}

variable "location" {}

variable "cognitiveServicesLocation" {}

variable "qna_tier" {
  default = "Free"
  description = "The tier for the chatbot application service plan.  Free, Shared, Standard"
}

variable "qna_size" {
  default = "F1"
  description = "The size for the chatbot qna service.  F1, D1, S1.  Only get one free one"
}

variable "search_sku" {
  default = "standard"
  description = "The sku to use for the azure search service"
}

variable "account_sku" {
  default = "S0"
  description = "The sku to use for the azure congative account"
}

variable "plan_id" {
  default = "",
  description = "The app service plan to use.  If none is passed it will create one"
}

variable "plan_reserved" {
  default =false
}