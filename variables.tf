variable "aws_region" {
    default = "-"
}

variable "meraki_api_key" {
    description = "X-Cisco-Meraki-API-Key" 
    type = string
    default = "-"
}

variable "network_id" {
    description = "Cisco Meraki Network ID" 
    type = string 
    default = "-"
}
