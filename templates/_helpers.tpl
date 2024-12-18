{{/*
Expand the name of the chart.
*/}}
{{- define "litmus-uns.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "litmus-uns.fullname" -}}
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
{{- define "litmus-uns.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "litmus-uns.labels" -}}
helm.sh/chart: {{ include "litmus-uns.chart" . }}
{{ include "litmus-uns.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "litmus-uns.selectorLabels" -}}
app.kubernetes.io/name: {{ include "litmus-uns.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "litmus-uns.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "litmus-uns.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the postgres host
*/}}
{{- define "postgres.host" -}}
{{- if .Values.postgres.external.enabled }}
  {{- .Values.postgres.external.host }}
{{- else }}
  {{- printf "postgres.%s.svc.cluster.local" .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Create the postgres port
*/}}
{{- define "postgres.port" -}}
{{- if .Values.postgres.external.enabled }}
{{- .Values.postgres.external.port }}
{{- else }}5432{{- end }}
{{- end }}

