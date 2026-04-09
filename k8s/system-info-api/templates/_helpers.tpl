{{/*
Expand the name of the chart.
*/}}
{{- define "system-info-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "system-info-api.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "system-info-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "system-info-api.labels" -}}
helm.sh/chart: {{ include "system-info-api.chart" . }}
{{ include "system-info-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "system-info-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "system-info-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the Kubernetes Secret to use
*/}}
{{- define "system-info-api.secretName" -}}
{{- if .Values.secret.name }}
{{- .Values.secret.name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-secret" (include "system-info-api.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common environment variables shared by the deployment
*/}}
{{- define "system-info-api.envVars" -}}
{{- with .Values.env }}
{{- toYaml . }}
{{- end }}
{{- if .Values.vault.enabled }}
- name: VAULT_SECRET_FILE
  value: {{ printf "/vault/secrets/%s" .Values.vault.fileName | quote }}
{{- end }}
{{- end }}

{{/*
Vault Agent Injector annotations
*/}}
{{- define "system-info-api.vaultAnnotations" -}}
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: {{ .Values.vault.role | quote }}
vault.hashicorp.com/auth-path: {{ .Values.vault.authPath | quote }}
vault.hashicorp.com/agent-inject-secret-{{ .Values.vault.fileName }}: {{ .Values.vault.secretPath | quote }}
{{- if .Values.vault.template }}
vault.hashicorp.com/agent-inject-template-{{ .Values.vault.fileName }}: |
{{ trim .Values.vault.template | indent 2 }}
{{- end }}
{{- if .Values.vault.command }}
vault.hashicorp.com/agent-inject-command-{{ .Values.vault.fileName }}: {{ .Values.vault.command | quote }}
{{- end }}
{{- range $key, $value := .Values.vault.extraAnnotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "system-info-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "system-info-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
