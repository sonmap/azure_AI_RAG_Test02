{
  "name": "${index_name}",
  "fields": [
    {
      "name": "id",
      "type": "Edm.String",
      "key": true,
      "filterable": true,
      "retrievable": true
    },
    {
      "name": "file_id",
      "type": "Edm.String",
      "filterable": true,
      "retrievable": true
    },
    {
      "name": "file_name",
      "type": "Edm.String",
      "searchable": true,
      "filterable": true,
      "sortable": true,
      "retrievable": true,
      "analyzer": "ko.microsoft"
    },
    {
      "name": "file_ext",
      "type": "Edm.String",
      "filterable": true,
      "facetable": true,
      "retrievable": true
    },
    {
      "name": "page_no",
      "type": "Edm.Int32",
      "filterable": true,
      "sortable": true,
      "retrievable": true
    },
    {
      "name": "slide_no",
      "type": "Edm.Int32",
      "filterable": true,
      "sortable": true,
      "retrievable": true
    },
    {
      "name": "chunk_no",
      "type": "Edm.Int32",
      "filterable": true,
      "sortable": true,
      "retrievable": true
    },
    {
      "name": "title",
      "type": "Edm.String",
      "searchable": true,
      "retrievable": true,
      "analyzer": "ko.microsoft"
    },
    {
      "name": "text",
      "type": "Edm.String",
      "searchable": true,
      "retrievable": true,
      "analyzer": "ko.microsoft"
    },
    {
      "name": "ocr_text",
      "type": "Edm.String",
      "searchable": true,
      "retrievable": true,
      "analyzer": "ko.microsoft"
    },
    {
      "name": "image_caption",
      "type": "Edm.String",
      "searchable": true,
      "retrievable": true,
      "analyzer": "ko.microsoft"
    },
    {
      "name": "source_blob_url",
      "type": "Edm.String",
      "retrievable": true
    },
    {
      "name": "pdf_blob_url",
      "type": "Edm.String",
      "retrievable": true
    },
    {
      "name": "thumb_blob_url",
      "type": "Edm.String",
      "retrievable": true
    },
    {
      "name": "updated_at",
      "type": "Edm.DateTimeOffset",
      "filterable": true,
      "sortable": true,
      "retrievable": true
    },
    {
      "name": "content_vector",
      "type": "Collection(Edm.Single)",
      "searchable": true,
      "retrievable": false,
      "dimensions": ${embedding_dimensions},
      "vectorSearchProfile": "vector-profile"
    }
  ],
  "semantic": {
    "defaultConfiguration": "semantic-config",
    "configurations": [
      {
        "name": "semantic-config",
        "prioritizedFields": {
          "titleField": {
            "fieldName": "title"
          },
          "prioritizedContentFields": [
            { "fieldName": "text" },
            { "fieldName": "ocr_text" },
            { "fieldName": "image_caption" }
          ],
          "prioritizedKeywordsFields": [
            { "fieldName": "file_name" },
            { "fieldName": "file_ext" }
          ]
        }
      }
    ]
  },
  "vectorSearch": {
    "profiles": [
      {
        "name": "vector-profile",
        "algorithm": "hnsw-config"
      }
    ],
    "algorithms": [
      {
        "name": "hnsw-config",
        "kind": "hnsw",
        "hnswParameters": {
          "metric": "cosine"
        }
      }
    ]
  }
}
