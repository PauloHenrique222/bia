#!/bin/bash

# Workflow completo: build, push e deploy
# Uso: ./scripts/full-deploy.sh [--commit-hash HASH] [--skip-build]

set -e

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções auxiliares
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse argumentos
COMMIT_HASH=""
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --commit-hash)
            COMMIT_HASH="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        *)
            log_error "Argumento desconhecido: $1"
            echo "Uso: $0 [--commit-hash HASH] [--skip-build]"
            exit 1
            ;;
    esac
done

# Preparar argumentos para scripts
ARGS=""
if [ -n "$COMMIT_HASH" ]; then
    ARGS="--commit-hash $COMMIT_HASH"
fi

log_info "=== WORKFLOW COMPLETO DE DEPLOY ==="

# Etapa 1: Build e Push (se não for para pular)
if [ "$SKIP_BUILD" = false ]; then
    log_info "Etapa 1/3: Build e Push da imagem..."
    if ! $SCRIPT_DIR/build-push.sh $ARGS; then
        log_error "Falha no build/push da imagem"
        exit 1
    fi
    log_success "Build e push concluídos"
    echo
else
    log_info "Etapa 1/3: Build e Push pulados (--skip-build)"
    echo
fi

# Etapa 2: Análise prévia
log_info "Etapa 2/3: Análise prévia (dry-run)..."
if ! $SCRIPT_DIR/deploy.sh --dry-run $ARGS; then
    log_error "Falha na análise prévia"
    exit 1
fi
echo

# Etapa 3: Deploy efetivo
log_info "Etapa 3/3: Deploy efetivo..."
if ! $SCRIPT_DIR/deploy.sh $ARGS; then
    log_error "Falha no deploy"
    exit 1
fi

log_success "=== WORKFLOW COMPLETO CONCLUÍDO ==="
