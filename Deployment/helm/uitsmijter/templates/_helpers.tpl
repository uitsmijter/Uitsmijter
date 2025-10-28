{{/*
Expand the name of the chart.
*/}}
{{- define "uitsmijter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "uitsmijter.fullname" -}}
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
{{- define "uitsmijter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "uitsmijter.labels" -}}
helm.sh/chart: {{ include "uitsmijter.chart" . }}
{{ include "uitsmijter.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "uitsmijter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "uitsmijter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "uitsmijter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "uitsmijter.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "uitsmijter.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}


{{/*
Build the default deployment name
*/}}
{{- define "uitsmijter.deploymentName" -}}
{{- default (include "uitsmijter.name" .) .Values.deploymentNameOverride }}-authserver
{{- end }}

{{/*
Build the default service name
*/}}
{{- define "uitsmijter.serviceName" -}}
{{- default (include "uitsmijter.name" .) .Values.serviceNameOverride }}-authserver
{{- end }}

{{/*
Define default resource limits and requests
Returns the resources from .Values.resources if set, otherwise returns sensible defaults
*/}}
{{- define "uitsmijter.resources" -}}
{{- if .Values.resources }}
{{- toYaml .Values.resources }}
{{- else }}
requests:
  memory: "256Mi"
  cpu: "250m"
limits:
  memory: "512Mi"
  cpu: "1000m"
{{- end }}
{{- end }}

{{/*
Generate or retrieve JWT secret
Looks up existing secret first to maintain persistence across upgrades
*/}}
{{- define "uitsmijter.jwtSecret" -}}
{{- if .Values.jwtSecret -}}
  {{- .Values.jwtSecret -}}
{{- else -}}
  {{- $secret := lookup "v1" "Secret" (include "uitsmijter.namespace" .) "jwt-secret" -}}
  {{- if and $secret $secret.data -}}
    {{- index $secret.data "JWT_SECRET" | b64dec -}}
  {{- else -}}
    {{- randAlphaNum 64 -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Generate or retrieve Redis password
Looks up existing secret first to maintain persistence across upgrades
*/}}
{{- define "uitsmijter.redisPassword" -}}
{{- if .Values.redisPassword -}}
  {{- .Values.redisPassword -}}
{{- else -}}
  {{- $secret := lookup "v1" "Secret" (include "uitsmijter.namespace" .) "uitsmijter-sessions" -}}
  {{- if and $secret $secret.data -}}
    {{- index $secret.data "redis-password" | b64dec -}}
  {{- else -}}
    {{- randAlphaNum 32 -}}
  {{- end -}}
{{- end -}}
{{- end -}}
