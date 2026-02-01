#!/bin/bash

# Deploy BIA com versionamento por commit hash
# Uso: ./scripts/deploy.sh [--dry-run] [--commit-hash HASH]

set -e

# Configurações
CLUSTER_NAME="cluster-bia"
SERVICE_NAME="service-bia"
TASK_FAMILY="task-def-bia"
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse argumentos
DRY_RUN=false
COMMIT_HASH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --commit-hash)
            COMMIT_HASH="$2"
            shift 2
            ;;
        *)
            log_error "Argumento desconhecido: $1"
            echo "Uso: $0 [--dry-run] [--commit-hash HASH]"
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

# Validar se commit hash existe
if [ -d ".git" ]; then
    if ! git cat-file -e "$COMMIT_HASH" 2>/dev/null; then
        log_error "Commit hash '$COMMIT_HASH' não encontrado no repositório"
        exit 1
    fi
fi

# Definir tag da imagem
IMAGE_TAG="$COMMIT_HASH"
FULL_IMAGE_URI="$ECR_REPO:$IMAGE_TAG"

log_info "=== DEPLOY BIA ==="
log_info "Cluster: $CLUSTER_NAME"
log_info "Service: $SERVICE_NAME"
log_info "Commit Hash: $COMMIT_HASH"
log_info "Image URI: $FULL_IMAGE_URI"
log_info "Dry Run: $DRY_RUN"
echo

# Verificar se imagem existe no ECR
log_info "Verificando se imagem existe no ECR..."
if aws ecr describe-images --repository-name bia --image-ids imageTag=$IMAGE_TAG --region $REGION >/dev/null 2>&1; then
    log_success "Imagem encontrada no ECR"
else
    log_error "Imagem $FULL_IMAGE_URI não encontrada no ECR"
    log_info "Execute primeiro: docker build -t bia:$IMAGE_TAG . && docker tag bia:$IMAGE_TAG $FULL_IMAGE_URI && docker push $FULL_IMAGE_URI"
    exit 1
fi

# Obter task definition atual
log_info "Obtendo task definition atual..."
CURRENT_TASK_DEF=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION)

# Criar nova task definition
log_info "Criando nova task definition..."
NEW_TASK_DEF=$(echo $CURRENT_TASK_DEF | jq --arg IMAGE "$FULL_IMAGE_URI" '
    .taskDefinition |
    .containerDefinitions[0].image = $IMAGE |
    del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy, .enableFaultInjection)
')

# Mostrar diferenças
log_info "=== ANÁLISE PRÉ-DEPLOY ==="
CURRENT_IMAGE=$(echo $CURRENT_TASK_DEF | jq -r '.taskDefinition.containerDefinitions[0].image')
log_info "Imagem atual: $CURRENT_IMAGE"
log_info "Nova imagem: $FULL_IMAGE_URI"

if [ "$DRY_RUN" = true ]; then
    log_warning "=== DRY RUN MODE ==="
    log_info "Nova task definition seria criada com:"
    echo $NEW_TASK_DEF | jq '.containerDefinitions[0] | {name, image, cpu, memoryReservation}'
    log_warning "Nenhuma alteração foi feita (dry-run mode)"
    exit 0
fi

# Confirmar deploy
echo
read -p "Deseja continuar com o deploy? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deploy cancelado pelo usuário"
    exit 0
fi

# Registrar nova task definition
log_info "Registrando nova task definition..."
echo $NEW_TASK_DEF > /tmp/task-def.json
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition --region $REGION --cli-input-json file:///tmp/task-def.json | jq -r '.taskDefinition.taskDefinitionArn')
rm -f /tmp/task-def.json
log_success "Nova task definition registrada: $NEW_TASK_DEF_ARN"

# Atualizar service
log_info "Atualizando service..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --task-definition $NEW_TASK_DEF_ARN \
    --region $REGION >/dev/null

log_success "Service atualizado com nova task definition"

# Aguardar deploy
log_info "Aguardando deploy completar..."
aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION

log_success "=== DEPLOY CONCLUÍDO ==="
log_info "Commit: $COMMIT_HASH"
log_info "Task Definition: $NEW_TASK_DEF_ARN"
log_info "Imagem: $FULL_IMAGE_URI"
