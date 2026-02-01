#!/bin/bash

# Rollback para versão anterior ou específica
# Uso: ./scripts/rollback.sh [--to-revision N] [--list-revisions]

set -e

# Configurações
CLUSTER_NAME="cluster-bia"
SERVICE_NAME="service-bia"
TASK_FAMILY="task-def-bia"
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
TO_REVISION=""
LIST_REVISIONS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --to-revision)
            TO_REVISION="$2"
            shift 2
            ;;
        --list-revisions)
            LIST_REVISIONS=true
            shift
            ;;
        *)
            log_error "Argumento desconhecido: $1"
            echo "Uso: $0 [--to-revision N] [--list-revisions]"
            exit 1
            ;;
    esac
done

# Listar revisões se solicitado
if [ "$LIST_REVISIONS" = true ]; then
    log_info "=== REVISÕES DISPONÍVEIS ==="
    aws ecs list-task-definitions --family-prefix $TASK_FAMILY --region $REGION --query 'taskDefinitionArns[]' --output table
    exit 0
fi

# Obter task definition atual do service
log_info "Obtendo configuração atual do service..."
CURRENT_TASK_DEF_ARN=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION --query 'services[0].taskDefinition' --output text)
CURRENT_REVISION=$(echo $CURRENT_TASK_DEF_ARN | grep -o '[0-9]*$')

log_info "Task definition atual: $CURRENT_TASK_DEF_ARN (revisão $CURRENT_REVISION)"

# Determinar revisão de destino
if [ -z "$TO_REVISION" ]; then
    # Rollback para revisão anterior
    TARGET_REVISION=$((CURRENT_REVISION - 1))
    if [ $TARGET_REVISION -lt 1 ]; then
        log_error "Não há revisão anterior disponível"
        exit 1
    fi
    log_info "Fazendo rollback para revisão anterior: $TARGET_REVISION"
else
    TARGET_REVISION=$TO_REVISION
    log_info "Fazendo rollback para revisão específica: $TARGET_REVISION"
fi

TARGET_TASK_DEF_ARN="arn:aws:ecs:$REGION:231284357002:task-definition/$TASK_FAMILY:$TARGET_REVISION"

# Verificar se task definition de destino existe
log_info "Verificando se task definition de destino existe..."
if ! aws ecs describe-task-definition --task-definition $TARGET_TASK_DEF_ARN --region $REGION >/dev/null 2>&1; then
    log_error "Task definition $TARGET_TASK_DEF_ARN não encontrada"
    log_info "Use --list-revisions para ver revisões disponíveis"
    exit 1
fi

# Obter detalhes da task definition de destino
TARGET_TASK_DEF=$(aws ecs describe-task-definition --task-definition $TARGET_TASK_DEF_ARN --region $REGION)
TARGET_IMAGE=$(echo $TARGET_TASK_DEF | jq -r '.taskDefinition.containerDefinitions[0].image')

log_info "=== ANÁLISE PRÉ-ROLLBACK ==="
CURRENT_TASK_DEF=$(aws ecs describe-task-definition --task-definition $CURRENT_TASK_DEF_ARN --region $REGION)
CURRENT_IMAGE=$(echo $CURRENT_TASK_DEF | jq -r '.taskDefinition.containerDefinitions[0].image')

log_info "Imagem atual: $CURRENT_IMAGE"
log_info "Imagem de destino: $TARGET_IMAGE"
log_warning "Rollback da revisão $CURRENT_REVISION para $TARGET_REVISION"

# Confirmar rollback
echo
read -p "Deseja continuar com o rollback? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rollback cancelado pelo usuário"
    exit 0
fi

# Executar rollback
log_info "Executando rollback..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --task-definition $TARGET_TASK_DEF_ARN \
    --region $REGION >/dev/null

log_success "Service atualizado para task definition: $TARGET_TASK_DEF_ARN"

# Aguardar rollback
log_info "Aguardando rollback completar..."
aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION

log_success "=== ROLLBACK CONCLUÍDO ==="
log_info "Revisão anterior: $CURRENT_REVISION"
log_info "Revisão atual: $TARGET_REVISION"
log_info "Imagem: $TARGET_IMAGE"
