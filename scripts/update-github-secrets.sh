#!/bin/bash
# Script para atualizar os secrets AWS em todos os repositórios do projeto
# Requer: GitHub CLI (gh) autenticado

set -e

REPOS=(
  "andersonfer/lanchonete-clientes"
  "andersonfer/lanchonete-pedidos"
  "andersonfer/lanchonete-pagamento"
  "andersonfer/lanchonete-cozinha"
)

echo "=== Atualizar AWS Secrets nos Repositórios GitHub ==="
echo ""

# Solicitar os secrets
read -p "AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
read -p "AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
read -p "AWS_SESSION_TOKEN: " AWS_SESSION_TOKEN

echo ""
echo "Atualizando secrets em ${#REPOS[@]} repositórios..."
echo ""

for repo in "${REPOS[@]}"; do
  echo ">>> $repo"

  echo "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID --repo "$repo"
  echo "    AWS_ACCESS_KEY_ID ✓"

  echo "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY --repo "$repo"
  echo "    AWS_SECRET_ACCESS_KEY ✓"

  echo "$AWS_SESSION_TOKEN" | gh secret set AWS_SESSION_TOKEN --repo "$repo"
  echo "    AWS_SESSION_TOKEN ✓"

  echo ""
done

echo "=== Concluído! ==="
echo ""
echo "Para verificar, acesse:"
for repo in "${REPOS[@]}"; do
  echo "  https://github.com/$repo/settings/secrets/actions"
done
