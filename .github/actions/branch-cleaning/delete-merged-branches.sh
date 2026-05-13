#!/bin/bash
#
# Script para deletar branches remotas desatualizadas sem novos commits.
#
# Lógica:
#   - Verifica se a branch está desatualizada em relação ao master
#   - Verifica se existem commits únicos na branch que não estão no master
#   - Só deleta se estiver desatualizada E não tiver novos commits
#
# Uso: ./delete-merged-branches.sh <base_branch> <protected_branches>
#
# Argumentos:
#   base_branch: Branch base para verificar merges (padrão: master)
#   protected_branches: Lista de branches protegidas separadas por vírgula
#

set -u

BASE_BRANCH="${1:-master}"
PROTECTED_BRANCHES="${2:-main,master,develop,homolog}"

# Arrays para tracking de resultados
declare -a DELETED_BRANCHES=()
declare -a PROTECTED_BRANCHES_SKIPPED=()
declare -a UNIQUE_COMMITS_BRANCHES=()
declare -a ERROR_BRANCHES=()

echo "🔍 Verificando branches desatualizadas em '$BASE_BRANCH'..."
echo "🛡️  Branches protegidas: $PROTECTED_BRANCHES"
echo ""

# Atualizar referências remotas
git fetch --prune origin 2>/dev/null || true

# Obter lista de branches remotas (excluindo HEAD e a base)
echo "📊 Analisando branches remotas..."
REMOTE_BRANCHES=$(git branch -r \
  | grep -v 'HEAD' \
  | sed 's|^ *origin/||' \
  | grep -v "^$BASE_BRANCH$" \
  | sort) || true

if [ -z "$REMOTE_BRANCHES" ]; then
  echo "✅ Nenhuma branch remota para analisar."
  exit 0
fi

echo "📋 Branches encontradas:"
echo "$REMOTE_BRANCHES" | sed 's/^/   • /'
echo ""

# Converter lista de branches protegidas em array
IFS=',' read -r -a PROTECTED_ARRAY <<< "$PROTECTED_BRANCHES"

echo "🔄 Processando branches..."
echo ""

# Iterar sobre branches remotas
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
    PROTECTED_BRANCHES_SKIPPED+=("$branch")
    continue
  fi

  # Verificar se a branch está desatualizada (seus commits estão em master)
  IS_MERGED=$(git merge-base --is-ancestor "origin/$branch" "origin/$BASE_BRANCH" && echo "true" || echo "false")

  if [ "$IS_MERGED" = "false" ]; then
    # Branch não foi mesclada ainda, pular
    continue
  fi

  # Verificar se há commits únicos na branch que não estão em master
  UNIQUE_COMMITS=$(git log "origin/$BASE_BRANCH..origin/$branch" --oneline 2>/dev/null | wc -l)

  if [ "$UNIQUE_COMMITS" -gt 0 ]; then
    # Branch tem commits únicos, não deletar
    UNIQUE_COMMITS_BRANCHES+=("$branch ($UNIQUE_COMMITS commit(s))")
  else
    # Branch está desatualizada e sem novos commits, pode deletar
    if git push origin --delete "$branch" 2>/dev/null; then
      DELETED_BRANCHES+=("$branch")
    else
      ERROR_BRANCHES+=("$branch")
    fi
  fi
done <<< "$REMOTE_BRANCHES"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "📊 RELATÓRIO FINAL DE LIMPEZA"
echo "════════════════════════════════════════════════════════════"
echo ""

# Branches deletadas
if [ ${#DELETED_BRANCHES[@]} -gt 0 ]; then
  echo "✅ Branches deletadas: ${#DELETED_BRANCHES[@]}"
  for branch in "${DELETED_BRANCHES[@]}"; do
    echo "   • $branch"
  done
  echo ""
fi

# Branches protegidas
if [ ${#PROTECTED_BRANCHES_SKIPPED[@]} -gt 0 ]; then
  echo "🛡️  Branches protegidas (não deletadas): ${#PROTECTED_BRANCHES_SKIPPED[@]}"
  for branch in "${PROTECTED_BRANCHES_SKIPPED[@]}"; do
    echo "   • $branch"
  done
  echo ""
fi

# Branches com commits únicos
if [ ${#UNIQUE_COMMITS_BRANCHES[@]} -gt 0 ]; then
  echo "⚠️  Branches com commits únicos (não deletadas): ${#UNIQUE_COMMITS_BRANCHES[@]}"
  for branch in "${UNIQUE_COMMITS_BRANCHES[@]}"; do
    echo "   • $branch"
  done
  echo ""
fi

# Branches com erro
if [ ${#ERROR_BRANCHES[@]} -gt 0 ]; then
  echo "❌ Branches com erro na exclusão: ${#ERROR_BRANCHES[@]}"
  for branch in "${ERROR_BRANCHES[@]}"; do
    echo "   • $branch (pode estar protegida no GitHub)"
  done
  echo ""
fi

echo "════════════════════════════════════════════════════════════"
echo ""
echo "✨ Processo finalizado com sucesso!"
echo ""
