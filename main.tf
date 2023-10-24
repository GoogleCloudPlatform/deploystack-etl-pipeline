/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
    type = string
}

variable "project_number" {
    type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "basename" {
  type = string
  default = "etlpipeline-tf"
}

# Enable APIs

variable "gcp_service_list" {
  description = "The list of apis necessary for the project"
  type        = list(string)
  default = [
    "dataflow.googleapis.com",
    "compute.googleapis.com",
    "composer.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "iam.googleapis.com"
  ]
}

resource "google_project_service" "all" {
  for_each           = toset(var.gcp_service_list)
  project            = var.project_number
  service            = each.key
  disable_on_destroy = false
}

# Create service account and assign roles
resource "google_service_account" "etl" {
  account_id   = "etlpipeline"
  display_name = "ETL SA"
  description  = "user-managed service account for Composer and Dataflow"
  project = var.project_id
  depends_on = [google_project_service.all]
}

variable "build_roles_list" {
  description = "The list of roles that Composer and Dataflow needs"
  type        = list(string)
  default = [
    "roles/composer.worker",
    "roles/dataflow.admin",
    "roles/dataflow.worker",
    "roles/bigquery.admin",
    "roles/storage.objectAdmin",
    "roles/dataflow.serviceAgent",
    "roles/composer.ServiceAgentV2Ext"
  ]
}

resource "google_project_iam_member" "allbuild" {
  project    = var.project_id
  for_each   = toset(var.build_roles_list)
  role       = each.key
  member     = "serviceAccount:${google_service_account.etl.email}"
  depends_on = [google_project_service.all,google_service_account.etl]
}

# Give Cloud Composer Service Agent the Cloud Composer v2 API Service Agent Extension role (required for Composer 2 environments)

resource "google_project_iam_member" "composerAgent" {
  project    = var.project_id
  role       = "roles/composer.ServiceAgentV2Ext"
  member     = "serviceAccount:service-${var.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"
  depends_on = [google_project_service.all]
}

# Create Composer environment
resource "google_composer_environment" "example" {
  project   = var.project_id
  name      = "example-environment"
  region    = var.region
  config {

    software_config {
      image_version = "composer-2.4.6-airflow-2.6.3"
      env_variables = {
        AIRFLOW_VAR_PROJECT_ID  = var.project_id
        AIRFLOW_VAR_GCE_ZONE    = var.zone
        AIRFLOW_VAR_BUCKET_PATH = "gs://${var.basename}-${var.project_id}-files"
        AIRFLOW_VAR_LOCATION = var.region
      }
    }
    node_config {
      service_account = google_service_account.etl.name
    }
  }
  depends_on = [google_project_service.all, google_service_account.etl, google_project_iam_member.allbuild, google_project_iam_member.composerAgent]
}

# Create BigQuery dataset and table

resource "google_bigquery_dataset" "weather_dataset" {
  project    = var.project_id
  dataset_id = "average_weather"
  location   = "US"
  depends_on = [google_project_service.all]
}

resource "google_bigquery_table" "weather_table" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.weather_dataset.dataset_id
  table_id   = "average_weather"
  deletion_protection = false

  schema     = <<EOF
[
  {
    "name": "location",
    "type": "GEOGRAPHY",
    "mode": "REQUIRED"
  },
  {
    "name": "average_temperature",
    "type": "INTEGER",
    "mode": "REQUIRED"
  },
   {
    "name": "month",
    "type": "STRING",
    "mode": "REQUIRED"
  },
   {
    "name": "inches_of_rain",
    "type": "NUMERIC",
    "mode": "NULLABLE"
  },
   {
    "name": "is_current",
    "type": "BOOLEAN",
    "mode": "NULLABLE"
  },
   {
    "name": "latest_measurement",
    "type": "DATE",
    "mode": "NULLABLE"
  }
]
EOF
  depends_on = [google_bigquery_dataset.weather_dataset]
}

# Create Cloud Storage bucket and add files
resource "google_storage_bucket" "pipeline_files" {
  project       = var.project_number
  name          = "${var.basename}-${var.project_id}-files"
  location      = "US"
  force_destroy = true
  depends_on    = [google_project_service.all]
}

resource "google_storage_bucket_object" "json_schema" {
  name       = "jsonSchema.json"
  source     = "${path.module}/files/jsonSchema.json"
  bucket     = google_storage_bucket.pipeline_files.name
  depends_on = [google_storage_bucket.pipeline_files]
}
resource "google_storage_bucket_object" "input_file" {
  name       = "inputFile.txt"
  source     = "${path.module}/files/inputFile.txt"
  bucket     = google_storage_bucket.pipeline_files.name
  depends_on = [google_storage_bucket.pipeline_files]
}
resource "google_storage_bucket_object" "transform_CSVtoJSON" {
  name       = "transformCSVtoJSON.js"
  source     = "${path.module}/files/transformCSVtoJSON.js"
  bucket     = google_storage_bucket.pipeline_files.name
  depends_on = [google_storage_bucket.pipeline_files]
}

# Upload DAG

data "google_composer_environment" "example" {
  project    = var.project_id
  region     = var.region
  name       = google_composer_environment.example.name
  depends_on = [google_composer_environment.example]
}

resource "google_storage_bucket_object" "dag_file" {
  name       = "dags/composer-dataflow-dag.py"
  source     = "${path.module}/files/composer-dataflow-dag.py"
  bucket     = replace(replace(data.google_composer_environment.example.config.0.dag_gcs_prefix, "gs://", ""),"/dags","")
  depends_on = [google_composer_environment.example, google_storage_bucket.pipeline_files, google_bigquery_table.weather_table]
}
