# Branch Cleaning — Composite Action

Limpa automaticamente branches remotas que foram totalmente mescladas em um branch base após merge em `master`, mantendo branches protegidas intactas.

## � Quick Start

**✅ Já está configurado e funcionando!**

O workflow **Pós-Merge** foi implementado em `.github/workflows/pos-merge.yml` e:
- ✅ Executa **automaticamente** quando há push para `master`
- ✅ Deleta branches mescladas e não protegidas
- ✅ Preserva branches críticas: `main`, `master`, `develop`
- ✅ Exibe feedback após conclusão

**Nenhuma configuração adicional é necessária** — use a ação como descrito abaixo para customizações.

## �📋 Visão geral

Esta Composite Action:
- ✅ Busca atualizações do repositório remoto (`git fetch --prune`)
- ✅ Identifica branches mescladas em um branch base
- ✅ Protege branches críticas (main, master, develop, homolog, etc.)
- ✅ Deleta apenas branches mescladas e não protegidas
- ✅ Fornece um resumo de operações realizadas
- ✅ Executa automaticamente após merge em `master`

## 🎯 Uso

### Workflow automático (Pós-Merge em master)

O workflow **Pós-Merge** está configurado em `.github/workflows/pos-merge.yml` e executa automaticamente quando há um `push` para a branch `master`.

#### Estrutura do workflow:

```yaml
name: Pós-Merge

on:
  push:
    branches:
      - master

jobs:
  cleanup_merged_branches:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - uses: ./.github/actions/branch-cleaning
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Feedback da execução
        if: success()
        run: echo "✅ Limpeza concluída. Branches mescladas na base foram removidas."
```

### Uso personalizado em outro workflow

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4
    with:
      fetch-depth: 0
  
  - name: Clean merged branches
    uses: ./.github/actions/branch-cleaning
    with:
      base-branch: develop
      protected-branches: main,master,develop,staging
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

## 🔧 Entradas (Inputs)

| Entrada | Descrição | Obrigatório | Padrão |
|---------|-----------|:-----------:|--------|
| `base-branch` | Branch base para verificar merges | ❌ | `master` |
| `protected-branches` | Branches protegidas (separadas por vírgula) | ❌ | `main,master,develop` |
| `github-token` | Token GitHub para permissão de escrita | ✅ | — |

## 📝 Exemplos

### Exemplo 1: Pós-Merge em master (padrão — já implementado)

Quando há um `push` para `master`, o workflow `Pós-Merge` executa automaticamente:

**Arquivo:** `.github/workflows/clean-merged-branches.yml`

```yaml
name: Pós-Merge

on:
  push:
    branches:
      - master

jobs:
  cleanup_merged_branches:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Executar Composite Action de limpeza de branches
        uses: ./.github/actions/branch-cleaning
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}

      - name: Feedback da execução
        if: success()
        run: echo "✅ Limpeza concluída. Branches mescladas na base foram removidas."
```

**Quando executa:**
- Automaticamente após qualquer push para `master`
- Limpa branches mescladas em `master`
- Preserva: `main`, `master`, `develop` (padrão)

---

### Exemplo 2: Workflow agendado (semanal)

Para limpeza automática sem aguardar merge:

```yaml
name: Weekly Branch Cleanup

on:
  schedule:
    # Segunda-feira, 09:00 UTC
    - cron: '0 9 * * MON'

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Clean merged branches
        uses: ./.github/actions/branch-cleaning
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

---

### Exemplo 3: Workflow manual com opções

Para controle manual via `workflow_dispatch`:

```yaml
name: Clean Branches (Manual)

on:
  workflow_dispatch:
    inputs:
      base-branch:
        description: Branch base
        required: false
        default: master
        type: choice
        options:
          - master
          - develop
          - main
      
      protected-branches:
        description: Branches protegidas (separadas por vírgula)
        required: false
        default: main,master,develop
        type: string

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Clean merged branches
        uses: ./.github/actions/branch-cleaning
        with:
          base-branch: ${{ inputs.base-branch }}
          protected-branches: ${{ inputs.protected-branches }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

---

### Exemplo 4: Após deploy em produção

Para limpeza com branches adicionais protegidas:

```yaml
name: Cleanup After Production Deploy

on:
  push:
    branches:
      - master

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Clean merged branches
        uses: ./.github/actions/branch-cleaning
        with:
          base-branch: master
          protected-branches: main,master,develop,staging,production
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## 🔐 Permissões necessárias

```yaml
permissions:
  contents: write  # Necessário para deletar branches remotas
```

## 📂 Estrutura de arquivos

```
.github/
├── actions/
│   └── branch-cleaning/
│       ├── action.yml                    # Definição da Composite Action
│       ├── delete-merged-branches.sh     # Script bash com lógica
│       └── README.md                     # Esta documentação
└── workflows/
    └── clean-merged-branches.yml         # Workflow Pós-Merge (já implementado)
```

**O workflow está pronto para usar** — executa automaticamente quando há push para `master`.

## 🛠️ Implementação interna

### `action.yml`
Define a Composite Action com entradas, descrição e a lógica de execução.

### `delete-merged-branches.sh`
Script bash que:
1. Busca atualizações do repositório (`git fetch --prune origin`)
2. Obtém lista de branches mescladas
3. Itera sobre cada branch mesclada
4. Valida se a branch não está protegida
5. Deleta branches mescladas e não protegidas
6. Exibe resumo com emojis para melhor legibilidade

## ⚙️ Comportamento esperado

### Execução automática após merge em master

Quando um PR é mergeado em `master`, o workflow **Pós-Merge** é acionado automaticamente:

1. ✅ Faz checkout completo do repositório
2. ✅ Executa a Composite Action `branch-cleaning`
3. ✅ Identifica branches mescladas
4. ✅ Deleta branches mescladas e não protegidas
5. ✅ Exibe feedback de conclusão

### Saída esperada

```
🔍 Verificando branches mescladas em 'master'...
🛡️  Branches protegidas: main,master,develop

🗑️  Deletando branch mesclada: feature/user-auth
🗑️  Deletando branch mesclada: fix/api-error
🛡️  Branch protegida, ignorando: develop

📊 Resumo:
  ✅ Branches deletadas: 2
  🛡️  Branches protegidas: 1

✅ Limpeza concluída. Branches mescladas na base foram removidas.
```

## 🐛 Troubleshooting

### Problema: Workflow não é acionado após merge em master
**Solução:** 
- Verifique se o arquivo `.github/workflows/pos-merge.yml` existe
- Confirme que a branch target é `master`
- Verifique a seção `on.push.branches` do workflow
- Aguarde alguns segundos (GitHub Actions pode ter delay)

### Problema: "permission denied" ao executar script
**Solução:** O script já é fornecido com permissão de execução. Se precisar resetar:
```bash
chmod +x .github/actions/branch-cleaning/delete-merged-branches.sh
```

### Problema: `git push origin --delete` falha
**Solução:** Verifique se:
- O `github-token` tem permissão `contents: write`
- A branch remota realmente existe
- Não há branch protegida pelo mesmo nome

### Problema: Branches não estão sendo deletadas
**Solução:** 
- Verifique se as branches estão realmente mescladas: `git branch -r --merged origin/master`
- Confirme que não estão na lista de `protected-branches`
- Valide que o histórico está disponível com `fetch-depth: 0`

### Problema: Feedback de conclusão não aparece
**Solução:**
- Verifique os logs do workflow no GitHub Actions
- Confirme que a ação anterior foi bem-sucedida (use `if: success()`)

## 📚 Referências

- [GitHub Actions — Composite actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Git branch management](https://git-scm.com/book/en/v2/Git-Branching-Branch-Management)
- [CRON expression reference](https://crontab.guru/)
