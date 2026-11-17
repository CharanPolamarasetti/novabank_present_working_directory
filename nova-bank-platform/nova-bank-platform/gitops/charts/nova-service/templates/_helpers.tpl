{{- define "nova.labels" -}}
app: {{ .Release.Name }}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/part-of: nova-bank
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment | default "dev" }}
{{- end -}}
{{- define "nova.selector" -}}
app: {{ .Release.Name }}
{{- end -}}
