resource "aws_glue_catalog_table" "numberblockedintrusionspastweek-view" {
  name = "numberblockedintrusionspastweek-view"
  database_name = var.database_name
  table_type = "VIRTUAL_VIEW"
  parameters = {
    presto_view = "true"
  }
  view_original_text = "/* Presto View: ${base64encode(
    jsonencode({
      originalSql = "SELECT table_meraki_security_report.destip, count(*) Frequency FROM table_meraki_security_report GROUP BY table_meraki_security_report.destip ORDER BY count(*) DESC LIMIT 10"
      catalog = "awsdatacatalog",
      schema = var.database_name,
      columns = [for c in var.columns : {name = c.name, type = c.presto_type}],
    })
  )} */"
  storage_descriptor {
    ser_de_info {
      name = "-"
      serialization_library = "-"
    }
    dynamic "columns" {
      for_each = var.columns
      content {
        name = columns.value.name
        type = columns.value.hive_type
      }
    }
  }
}

  resource "aws_glue_catalog_table" "mostfrequentdestinationips-view" {
    name = "mostfrequentdestinationips-view"
    database_name = var.database_name
    table_type = "VIRTUAL_VIEW"
    parameters = {
      presto_view = "true"
    }
    view_original_text = "/* Presto View: ${base64encode(
      jsonencode({
        originalSql = "SELECT count(ts) numberofevents FROM table_meraki_security_report"
        catalog = "awsdatacatalog",
        schema = var.database_name,
        columns = [for c in var.columns : {name = c.name, type = c.presto_type}],
      })
    )} */"
    storage_descriptor {
      ser_de_info {
        name = "-"
        serialization_library = "-"
      }
      dynamic "columns" {
        for_each = var.columns
        content {
          name = columns.value.name
          type = columns.value.hive_type
        }
      }
    }
}

resource "aws_glue_catalog_table" "mostfrequentattacktypes-view" {
    name = "mostfrequentattacktypes-view"
    database_name = var.database_name
    table_type = "VIRTUAL_VIEW"
    parameters = {
      presto_view = "true"
    }
    view_original_text = "/* Presto View: ${base64encode(
      jsonencode({
        originalSql = "SELECT message, count(*) Frequency FROM table_meraki_security_report GROUP BY message ORDER BY count(*) DESC LIMIT 10"
        catalog = "awsdatacatalog",
        schema = var.database_name,
        columns = [for c in var.columns : {name = c.name, type = c.presto_type}],
      })
    )} */"
    storage_descriptor {
      ser_de_info {
        name = "-"
        serialization_library = "-"
      }
      dynamic "columns" {
        for_each = var.columns
        content {
          name = columns.value.name
          type = columns.value.hive_type
        }
      }
    }
}