variable "database_name" {
  type = string
  default = "merakisecurityevents"
}

variable "columns" {
  type = list(object({
    name = string
    hive_type = string
    presto_type = string}))
  default = [
    {
      name = "ts"
      hive_type = "string"
      presto_type = "string"
    }, 
    {
      name = "message"
      hive_type = "string"
      presto_type = "string"
    }, 
    {
      name = "destip"
      hive_type = "string"
      presto_type = "string"
    }, 
  ]
}
