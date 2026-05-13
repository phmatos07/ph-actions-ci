#!/bin/bash
#
# Script para deletar branches remotas que foram mescladas em um branch base.
#
# Uso: ./delete-merged-branches.sh <base_branch> <protected_branches>
#
# Argumentos:
#   base_branch: Branch base para verificar merges (padrão: master)
#   protected_branches: Lista de branches protegidas separadas por vírgula
#

set -euo pipefail

BASE_BRANCH="${1:-master}"
PROTECTED_BRANCHES="${2:-main,master,develop}"

echo "🔍 Verificando branches mescladas em '$BASE_BRANCH'..."
echo "🛡️  Branches protegidas: $PROTECTED_BRANCHES"
echo ""

# Buscar atualizações do repositório remoto
git fetch --prune origin

# Obter lista de branches mescladas (excluindo HEAD)
MERGED_BRANCHES=$(git branch -r --merged "origin/$BASE_BRANCH" \
  | grep -v 'HEAD' \
  | sed 's|^ *origin/||') || true

if [ -z "$MERGED_BRANCHES" ]; then
  echo "✅ Nenhuma branch mesclada encontrada."
  exit 0
fi

# Converter lista de branches protegidas em array
IFS=',' read -r -a PROTECTED_ARRAY <<< "$PROTECTED_BRANCHES"

DELETED_COUNT=0
PROTECTED_COUNT=0

# Iterar sobre branches mescladas
while IFS= read -r branch; do
  if [ -z "$branch" ]; then
    continue
  fi

  # Verificar se a branch está protegida
  IS_PROTECTED=false
  for protected_branch in "${PROTECTED_ARRAY[@]}"; do
    protected_branch=$(echo "$protected_branch" | xargs) # Trim whitespace
    if [ "$branch" = "$protected_branch" ]; then
      IS_PROTECTED=true
      break
    fi
  done

  if [ "$IS_PROTECTED" = "true" ]; then
    echo "🛡️  Branch protegida, ignorando: $branch"
    ((PROTECTED_COUNT++))
  else
    echo "🗑️  Deletando branch mesclada: $branch"
    git push origin --delete "$branch"
    ((DELETED_COUNT++))
  fi
done <<< "$MERGED_BRANCHES"

echo ""
echo "📊 Resumo:"
echo "  ✅ Branches deletadas: $DELETED_COUNT"
echo "  🛡️  Branches protegidas: $PROTECTED_COUNT"
