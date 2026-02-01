#!/bin/bash

# Build e push da imagem BIA para ECR com commit hash
# Uso: ./scripts/build-push.sh [--commit-hash HASH]

set -e

# Configurações
ECR_REPO="231284357002.dkr.ecr.us-east-1.amazonaws.com/bia"
REGION="us-east-1"

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

while [[ $# -gt 0 ]]; do
    case $1 in
        --commit-hash)
            COMMIT_HASH="$2"
            shift 2
            ;;
        *)
            log_error "Argumento desconhecido: $1"
            echo "Uso: $0 [--commit-hash HASH]"
            exit 1
            ;;
    esac
done

# Obter commit hash se não fornecido
if [ -z "$COMMIT_HASH" ]; then
    if [ -d ".git" ]; then
        COMMIT_HASH=$(git rev-parse --short HEAD)
        log_info "Usando commit hash atual: $COMMIT_HASH"
    else
        log_error "Não é um repositório git e --commit-hash não foi fornecido"
        exit 1
    fi
fi

# Definir tag da imagem
IMAGE_TAG="$COMMIT_HASH"
FULL_IMAGE_URI="$ECR_REPO:$IMAGE_TAG"

log_info "=== BUILD & PUSH BIA ==="
log_info "Commit Hash: $COMMIT_HASH"
log_info "Image URI: $FULL_IMAGE_URI"
echo

# Verificar se Dockerfile existe
if [ ! -f "Dockerfile" ]; then
    log_error "Dockerfile não encontrado no diretório atual"
    exit 1
fi

# Login no ECR
log_info "Fazendo login no ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO

# Build da imagem
log_info "Fazendo build da imagem..."
docker build -t bia:$IMAGE_TAG .

# Tag da imagem
log_info "Taggeando imagem..."
docker tag bia:$IMAGE_TAG $FULL_IMAGE_URI

# Push da imagem
log_info "Fazendo push da imagem..."
docker push $FULL_IMAGE_URI

log_success "=== BUILD & PUSH CONCLUÍDO ==="
log_info "Imagem: $FULL_IMAGE_URI"
log_info "Agora você pode executar: ./scripts/deploy.sh --commit-hash $COMMIT_HASH"
