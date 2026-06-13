locals {
  search_index_payload_content = templatefile("${path.module}/../../scripts/search_index_payload.json.tpl", {
    index_name           = var.search_index_name
    embedding_dimensions = var.embedding_dimensions
  })
}

resource "local_file" "search_index_payload" {
  count    = var.create_search_index ? 1 : 0
  filename = "${path.module}/generated_search_index_payload.json"
  content  = local.search_index_payload_content
}

resource "null_resource" "create_search_index" {
  count = var.create_search_index ? 1 : 0

  depends_on = [
    module.search,
    local_file.search_index_payload
  ]

  triggers = {
    # local_file가 실제 파일을 만들기 전에 filesha256()를 호출하면 오류가 납니다.
    # 그래서 파일 경로가 아니라 template content 자체를 hash 처리합니다.
    payload_sha     = sha256(local.search_index_payload_content)
    search_endpoint = module.search.endpoint
    index_name      = var.search_index_name
  }

  provisioner "local-exec" {
    command = <<EOT
bash ${path.module}/../../scripts/create_search_index.sh \
  "${module.search.endpoint}" \
  "${module.resource_group.name}" \
  "${module.search.name}" \
  "${var.search_index_name}" \
  "${local_file.search_index_payload[0].filename}"
EOT
  }
}
