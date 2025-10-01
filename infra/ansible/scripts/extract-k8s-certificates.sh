#!/bin/bash
# Script para extraer certificados del kubeconfig y crear PKCS#12 (.pfx)
# Este archivo .pfx se usa en Octopus Deploy para autenticación con Kubernetes

set -e

KUBECONFIG_FILE="${1:-./kubeconfig-dev.yaml}"
OUTPUT_DIR="./k8s-certs"
PFX_FILE="k8s-dev-admin-cert.pfx"
PFX_PASSWORD="${2:-tunefy-dev-2025}"  # Contraseña por defecto, cambiar en producción

echo "=================================================="
echo "  Extrayendo Certificados de Kubeconfig"
echo "=================================================="
echo "Kubeconfig: $KUBECONFIG_FILE"
echo "Output Directory: $OUTPUT_DIR"
echo "PFX File: $PFX_FILE"
echo ""

# Verificar que el kubeconfig existe
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "❌ Error: Kubeconfig no encontrado en $KUBECONFIG_FILE"
    exit 1
fi

# Crear directorio de output
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "📄 Paso 1: Extrayendo certificados del kubeconfig..."

# Método alternativo: extraer directamente del YAML usando grep/awk/base64
# No requiere kubectl instalado localmente

# Extraer client certificate
echo "   - Extrayendo client.crt..."
grep 'client-certificate-data:' "../$KUBECONFIG_FILE" | awk '{print $2}' | base64 -d > client.crt

if [ ! -s client.crt ]; then
    echo "❌ Error: No se pudo extraer client.crt"
    exit 1
fi

# Extraer client key
echo "   - Extrayendo client.key..."
grep 'client-key-data:' "../$KUBECONFIG_FILE" | awk '{print $2}' | base64 -d > client.key

if [ ! -s client.key ]; then
    echo "❌ Error: No se pudo extraer client.key"
    exit 1
fi

# Extraer CA certificate
echo "   - Extrayendo ca.crt..."
grep 'certificate-authority-data:' "../$KUBECONFIG_FILE" | awk '{print $2}' | base64 -d > ca.crt

if [ ! -s ca.crt ]; then
    echo "❌ Error: No se pudo extraer ca.crt"
    exit 1
fi

echo "✅ Certificados extraídos exitosamente"
echo ""

# Verificar los certificados
echo "🔍 Verificando certificados..."
echo ""
echo "Client Certificate Info:"
openssl x509 -in client.crt -noout -subject -issuer -dates | sed 's/^/   /'
echo ""
echo "CA Certificate Info:"
openssl x509 -in ca.crt -noout -subject -issuer -dates | sed 's/^/   /'
echo ""

# Crear PKCS#12 (.pfx)
echo "📦 Paso 2: Creando archivo PKCS#12 (.pfx)..."
echo "   Contraseña: $PFX_PASSWORD"
echo ""

openssl pkcs12 -export \
    -in client.crt \
    -inkey client.key \
    -certfile ca.crt \
    -name "k8s-dev-admin-cert" \
    -out "$PFX_FILE" \
    -password "pass:$PFX_PASSWORD"

if [ ! -f "$PFX_FILE" ]; then
    echo "❌ Error: No se pudo crear el archivo .pfx"
    exit 1
fi

echo "✅ Archivo PKCS#12 creado exitosamente"
echo ""

# Verificar el .pfx
echo "🔍 Verificando archivo .pfx..."
openssl pkcs12 -in "$PFX_FILE" -noout -info -password "pass:$PFX_PASSWORD" 2>&1 | head -5 | sed 's/^/   /'
echo ""

# Resumen de archivos generados
echo "📁 Archivos generados en $OUTPUT_DIR:"
ls -lh client.crt client.key ca.crt "$PFX_FILE" | awk '{print "   " $9 " (" $5 ")"}'
echo ""

# Información importante
echo "=================================================="
echo "  ✅ Certificados Listos"
echo "=================================================="
echo ""
echo "📋 Archivos individuales (para referencia):"
echo "   - client.crt: Certificado del cliente"
echo "   - client.key: Llave privada del cliente"
echo "   - ca.crt: Certificado de la CA del cluster"
echo ""
echo "📦 Archivo para Octopus Deploy:"
echo "   - $PFX_FILE"
echo "   - Contraseña: $PFX_PASSWORD"
echo ""
echo "🎯 Uso en Octopus Deploy:"
echo "   1. Infrastructure → Accounts → Add Account"
echo "   2. Account Type: Token"
echo "   3. Token: Subir el archivo $PFX_FILE"
echo "   4. Password: $PFX_PASSWORD"
echo ""
echo "   O en Kubernetes Target:"
echo "   1. Authentication: Client Certificate"
echo "   2. Certificate: Subir $PFX_FILE"
echo "   3. Password: $PFX_PASSWORD"
echo "   4. Cluster URL: https://10.20.90.15:6443"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - Guardar la contraseña en un lugar seguro"
echo "   - Este certificado tiene permisos de cluster-admin"
echo "   - Solo usar en ambiente Dev"
echo "   - Para QA/Prod, crear service accounts con RBAC limitado"
echo ""
echo "=================================================="
