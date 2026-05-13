#!/bin/bash
#
# Script para deletar branches remotas que foram mescladas ou estão desatualizadas em relação a um branch base.
#
# Uso: ./delete-merged-branches.sh <base_branch> <protected_branches>
#
# Argumentos:
#   base_branch: Branch base para verificar merges (padrão: master)
#   protected_branches: Lista de branches protegidas separadas por vírgula
#
# O script deleta branches que:
#   1. Foram completamente mescladas em BASE_BRANCH (git merge)
#   2. Não têm commits únicos em relação a BASE_BRANCH (desatualizadas)
#

set -euo pipefail

BASE_BRANCH="${1:-master}"
PROTECTED_BRANCHES="${2:-main,master,develop}"

echo "🔍 Verificando branches mescladas ou desatualizadas em '$BASE_BRANCH'..."
echo "🛡️  Branches protegidas: $PROTECTED_BRANCHES"
echo ""

# Buscar atualizações do repositório remoto
git fetch --prune origin

# Converter lista de branches protegidas em array
IFS=',' read -r -a PROTECTED_ARRAY <<< "$PROTECTED_BRANCHES"

DELETED_COUNT=0
PROTECTED_COUNT=0
SKIPPED_COUNT=0

# Obter lista de todas as branches remotas (excluindo HEAD)
ALL_BRANCHES=$(git branch -r \
  | grep -v 'HEAD' \
  | sed 's|^ *origin/||' \
  | grep -v "^$BASE_BRANCH$") || true

if [ -z "$ALL_BRANCHES" ]; then
  echo "✅ Nenhuma branch encontrada para verificação."
  exit 0
fi

# Função para verificar se a branch está protegida
is_protected() {
  local branch="$1"
  for protected_branch in "${PROTECTED_ARRAY[@]}"; do
    protected_branch=$(echo "$protected_branch" | xargs) # Trim whitespace
    if [ "$branch" = "$protected_branch" ]; then
      return 0
    fi
  done
  return 1
}

# Função para verificar se a branch tem commits únicos em relação à base
has_unique_commits() {
  local branch="$1"
  local base="$2"
  
  # Contar commits únicos na branch que não estão na base
  local unique_commits=$(git rev-list --left-only --count "origin/$base...origin/$branch" 2>/dev/null || echo "0")
  
  if [ "$unique_commits" -gt 0 ]; then
    return 0 # Tem commits únicos
  else
    return 1 # Não tem commits únicos (está desatualizada ou mesclada)
  fi
}

# Iterar sobre todas as branches
while IFS= read -r branch; do
  if [ -z "$branch" ]; then
    continue
  fi

  # Verificar se a branch está protegida
  if is_protected "$branch"; then
    echo "🛡️  Branch protegida, ignorando: $branch"
    ((PROTECTED_COUNT++))
    continue
  fi

  # Verificar se a branch tem commits únicos
  if ! has_unique_commits "$branch" "$BASE_BRANCH"; then
    # Branch não tem commits únicos = está mesclada ou desatualizada
    echo "🗑️  Deletando branch: $branch (sem commits únicos em relação a $BASE_BRANCH)"
    git push origin --delete "$branch" 2>/dev/null || {
      echo "⚠️  Erro ao deletar $branch"
      ((SKIPPED_COUNT++))
      continue
    }
    ((DELETED_COUNT++))
  else
    # Branch tem commits únicos = mantém
    echo "✅ Branch mantida (tem commits únicos): $branch"
    ((SKIPPED_COUNT++))
  fi
done <<< "$ALL_BRANCHES"

echo ""
echo "📊 Resumo:"
echo "  ✅ Branches deletadas: $DELETED_COUNT"
echo "  ✨ Branches mantidas (com commits): $SKIPPED_COUNT"
echo "  🛡️  Branches protegidas: $PROTECTED_COUNT"
