{{- define "platform-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-api.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "platform-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-api.environment" -}}
{{- required "platform-api: .Values.environment must be one of dev|staging|prod" .Values.environment -}}
{{- end -}}

{{- define "platform-api.instance" -}}
{{- printf "%s-%s" (include "platform-api.name" .) (include "platform-api.environment" .) -}}
{{- end -}}

{{- define "platform-api.version" -}}
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{- define "platform-api.image" -}}
{{- printf "%s:%s" .Values.image.repository (include "platform-api.version" .) -}}
{{- end -}}

{{- define "platform-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-api.name" . }}
app.kubernetes.io/instance: {{ include "platform-api.instance" . }}
{{- end -}}

{{- define "platform-api.labels" -}}
helm.sh/chart: {{ include "platform-api.chart" . }}
{{ include "platform-api.selectorLabels" . }}
app.kubernetes.io/version: {{ include "platform-api.version" . | quote }}
app.kubernetes.io/component: api
app.kubernetes.io/part-of: platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "platform-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "platform-api.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "platform-api.stableServiceName" -}}
{{- include "platform-api.fullname" . -}}
{{- end -}}

{{- define "platform-api.canaryServiceName" -}}
{{- printf "%s-canary" (include "platform-api.fullname" .) -}}
{{- end -}}

{{- define "platform-api.configMapName" -}}
{{- printf "%s-config" (include "platform-api.fullname" .) -}}
{{- end -}}

{{- define "platform-api.secretName" -}}
{{- printf "%s-secrets" (include "platform-api.fullname" .) -}}
{{- end -}}

{{- define "platform-api.analysisTemplateName" -}}
{{- printf "%s-success-rate" (include "platform-api.fullname" .) -}}
{{- end -}}

{{- define "platform-api.podEnv" -}}
- name: SERVER_PORT
  value: {{ .Values.containerPorts.http | quote }}
- name: MANAGEMENT_SERVER_PORT
  value: {{ .Values.containerPorts.management | quote }}
{{- if .Values.otel.enabled }}
- name: JAVA_TOOL_OPTIONS
  value: "-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError -javaagent:/otel/opentelemetry-javaagent.jar"
- name: OTEL_SERVICE_NAME
  value: {{ include "platform-api.name" . }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "service.namespace=platform,deployment.environment={{ include "platform-api.environment" . }}"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.otel.endpoint | quote }}
- name: OTEL_TRACES_SAMPLER
  value: parentbased_traceidratio
- name: OTEL_TRACES_SAMPLER_ARG
  value: {{ .Values.otel.samplerArg | quote }}
- name: OTEL_METRICS_EXPORTER
  value: none
- name: OTEL_LOGS_EXPORTER
  value: none
{{- end }}
{{- with .Values.extraEnv }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end -}}

{{- define "platform-api.podSpec" -}}
serviceAccountName: {{ include "platform-api.serviceAccountName" . }}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if .Values.topologySpread.enabled }}
topologySpreadConstraints:
  - maxSkew: {{ .Values.topologySpread.maxSkew }}
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: {{ .Values.topologySpread.whenUnsatisfiable }}
    labelSelector:
      matchLabels:
        {{- include "platform-api.selectorLabels" . | nindent 8 }}
  - maxSkew: {{ .Values.topologySpread.maxSkew }}
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: {{ .Values.topologySpread.whenUnsatisfiable }}
    labelSelector:
      matchLabels:
        {{- include "platform-api.selectorLabels" . | nindent 8 }}
{{- end }}
containers:
  - name: {{ include "platform-api.name" . }}
    image: {{ include "platform-api.image" . }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    securityContext:
      {{- toYaml .Values.securityContext | nindent 6 }}
    ports:
      - name: http
        containerPort: {{ .Values.containerPorts.http }}
        protocol: TCP
      - name: management
        containerPort: {{ .Values.containerPorts.management }}
        protocol: TCP
    env:
      {{- include "platform-api.podEnv" . | nindent 6 }}
    envFrom:
      - configMapRef:
          name: {{ include "platform-api.configMapName" . }}
      {{- if .Values.externalSecrets.enabled }}
      - secretRef:
          name: {{ include "platform-api.secretName" . }}
      {{- end }}
    startupProbe:
      httpGet:
        path: {{ .Values.probes.startup.path }}
        port: management
      initialDelaySeconds: {{ .Values.probes.startup.initialDelaySeconds }}
      periodSeconds: {{ .Values.probes.startup.periodSeconds }}
      timeoutSeconds: {{ .Values.probes.startup.timeoutSeconds }}
      failureThreshold: {{ .Values.probes.startup.failureThreshold }}
    livenessProbe:
      httpGet:
        path: {{ .Values.probes.liveness.path }}
        port: management
      initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
      periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
      timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds }}
      failureThreshold: {{ .Values.probes.liveness.failureThreshold }}
    readinessProbe:
      httpGet:
        path: {{ .Values.probes.readiness.path }}
        port: management
      initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
      periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
      timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds }}
      failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
    lifecycle:
      preStop:
        exec:
          command: ["sleep", "{{ .Values.lifecycle.preStopSleepSeconds }}"]
    resources:
      {{- toYaml .Values.resources | nindent 6 }}
    volumeMounts:
      - name: tmp
        mountPath: /tmp
      {{- with .Values.extraVolumeMounts }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
volumes:
  - name: tmp
    emptyDir: {}
  {{- with .Values.extraVolumes }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}
