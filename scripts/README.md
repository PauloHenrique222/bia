# Scripts de Deploy BIA

Scripts para deploy com versionamento por commit hash no ECS.

## Scripts Disponíveis

### 1. build-push.sh
Build e push da imagem Docker para ECR com tag baseada no commit hash.

```bash
# Build e push com commit atual
./scripts/build-push.sh

# Build e push com commit específico
./scripts/build-push.sh --commit-hash abc1234
```

### 2. deploy.sh
Deploy da aplicação no ECS com versionamento por commit hash.

```bash
# Deploy com commit atual
./scripts/deploy.sh

# Deploy com commit específico
./scripts/deploy.sh --commit-hash abc1234

# Análise prévia (dry-run)
./scripts/deploy.sh --dry-run

# Análise prévia com commit específico
./scripts/deploy.sh --dry-run --commit-hash abc1234
```

### 3. rollback.sh
Rollback para versões anteriores.

```bash
# Rollback para versão anterior
./scripts/rollback.sh

# Rollback para revisão específica
./scripts/rollback.sh --to-revision 5

# Listar revisões disponíveis
./scripts/rollback.sh --list-revisions
```

### 4. full-deploy.sh
Workflow completo: build, push e deploy em uma única execução.

```bash
# Workflow completo com commit atual
./scripts/full-deploy.sh

# Workflow completo com commit específico
./scripts/full-deploy.sh --commit-hash abc1234

# Deploy sem build (imagem já existe)
./scripts/full-deploy.sh --skip-build
```

## Fluxo de Trabalho

### Deploy Completo (Recomendado)
```bash
# Workflow completo automático
./scripts/full-deploy.sh
```

### Deploy Manual (Passo a Passo)
```bash
# 1. Build e push da imagem
./scripts/build-push.sh

# 2. Análise prévia
./scripts/deploy.sh --dry-run

# 3. Deploy efetivo
./scripts/deploy.sh
```

### Deploy com Commit Específico
```bash
# 1. Build e push com commit específico
./scripts/build-push.sh --commit-hash abc1234

# 2. Deploy com mesmo commit
./scripts/deploy.sh --commit-hash abc1234
```

### Rollback
```bash
# Ver revisões disponíveis
./scripts/rollback.sh --list-revisions

# Rollback para versão anterior
./scripts/rollback.sh

# Rollback para revisão específica
./scripts/rollback.sh --to-revision 3
```

## Versionamento

- **Tag da Imagem:** Baseada no commit hash (ex: `abc1234`)
- **Task Definition:** Nova revisão criada para cada deploy
- **Rastreabilidade:** Cada versão é rastreável pelo commit hash

## Recursos

- ✅ Versionamento por commit hash
- ✅ Análise prévia com --dry-run
- ✅ Confirmação antes do deploy
- ✅ Rollback simples
- ✅ Logs coloridos e informativos
- ✅ Validação de imagem no ECR
- ✅ Aguarda deploy completar

## Configuração

Os scripts usam as seguintes configurações:
- **Cluster:** cluster-bia
- **Service:** service-bia
- **Task Family:** task-def-bia
- **ECR Repo:** 231284357002.dkr.ecr.us-east-1.amazonaws.com/bia
- **Region:** us-east-1

## Pré-requisitos

- AWS CLI configurado
- Docker instalado
- jq instalado
- Repositório git (para commit hash automático)
