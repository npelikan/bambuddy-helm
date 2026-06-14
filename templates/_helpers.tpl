{{/*
Expand the name of the chart.
*/}}
{{- define "bambuddy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "bambuddy.fullname" -}}
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
{{- define "bambuddy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bambuddy.labels" -}}
helm.sh/chart: {{ include "bambuddy.chart" . }}
{{ include "bambuddy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bambuddy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bambuddy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "bambuddy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "bambuddy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image reference, using appVersion as the default tag.
*/}}
{{- define "bambuddy.image" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/*
Name of the application Secret managed by this chart.
*/}}
{{- define "bambuddy.secretName" -}}
{{- printf "%s" (include "bambuddy.fullname" .) -}}
{{- end }}

{{/*
PVC name for the data volume.
*/}}
{{- define "bambuddy.dataClaimName" -}}
{{- if .Values.persistence.data.existingClaim -}}
{{- .Values.persistence.data.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "bambuddy.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
PVC name for the logs volume.
*/}}
{{- define "bambuddy.logsClaimName" -}}
{{- if .Values.persistence.logs.existingClaim -}}
{{- .Values.persistence.logs.existingClaim -}}
{{- else -}}
{{- printf "%s-logs" (include "bambuddy.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Whether this chart needs to manage its own Secret (i.e. there is at least one
inline secret value that is not delegated to an existing Secret).
Returns the string "true" when a Secret should be created, otherwise "".
*/}}
{{- define "bambuddy.createSecret" -}}
{{- $create := false -}}
{{- if and (eq .Values.database.type "postgresql") (not .Values.database.externalDatabase.existingSecret) -}}
{{- $create = true -}}
{{- end -}}
{{- if and .Values.config.homeAssistant.token (not .Values.config.homeAssistant.existingSecret) -}}
{{- $create = true -}}
{{- end -}}
{{- if and .Values.config.mfa.encryptionKey (not .Values.config.mfa.existingSecret) -}}
{{- $create = true -}}
{{- end -}}
{{- if $create -}}true{{- end -}}
{{- end }}

{{/*
Build the DATABASE_URL value for PostgreSQL when an explicit `url` is not set.
The password is intentionally NOT included here; it is referenced separately so
that the assembled URL can live in the managed Secret with the password inlined.
This helper returns the full URL *including* the password and is only used to
populate the managed Secret. Validation of required fields happens here.
*/}}
{{- define "bambuddy.postgresUrl" -}}
{{- $db := .Values.database.externalDatabase -}}
{{- if $db.url -}}
{{- $db.url -}}
{{- else -}}
{{- if not $db.host -}}
{{- fail "database.externalDatabase.host is required when database.type=postgresql and no externalDatabase.url is provided" -}}
{{- end -}}
{{- $pass := $db.password -}}
{{- $base := printf "postgresql+asyncpg://%s:%s@%s:%v/%s" $db.user $pass $db.host (toString $db.port) $db.database -}}
{{- if $db.sslmode -}}
{{- printf "%s?sslmode=%s" $base $db.sslmode -}}
{{- else -}}
{{- $base -}}
{{- end -}}
{{- end -}}
{{- end }}
