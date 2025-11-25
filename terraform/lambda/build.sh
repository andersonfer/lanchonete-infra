#!/bin/bash

# Script para build da Lambda de autenticação em Java
# Uso: ./build.sh

set -e

echo "🏗️  Iniciando build da Lambda de autenticação..."

# Verificar se Maven está disponível
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven não encontrado. Instale o Maven para continuar."
    exit 1
fi

# Executar testes unitários
echo "🧪 Executando testes unitários..."
mvn clean test
if [ $? -ne 0 ]; then
    echo "❌ Testes falharam! Build interrompido."
    exit 1
fi
echo "✅ Todos os testes passaram!"

# Compilar o projeto Java
echo "📦 Compilando projeto Java..."
mvn package -DskipTests

# Verificar se o build foi bem-sucedido
if [ ! -d "target" ]; then
    echo "❌ Build falhou. Diretório target não encontrado."
    exit 1
fi

# Encontrar o JAR principal (excluindo original)
JAR_FILE=$(find target -name "*-shaded.jar" -o -name "lanchonete-auth-lambda-*.jar" | grep -v original | head -n 1)

if [ -z "$JAR_FILE" ]; then
    # Se não encontrar shaded, pegar qualquer JAR que não seja original
    JAR_FILE=$(find target -name "*.jar" | grep -v original | head -n 1)
fi

if [ -z "$JAR_FILE" ]; then
    echo "❌ JAR não encontrado no diretório target/"
    exit 1
fi

echo "📁 JAR encontrado: $JAR_FILE"

# Remover ZIP anterior se existir
if [ -f "lambda-auth.zip" ]; then
    rm lambda-auth.zip
    echo "🗑️  ZIP anterior removido"
fi

# Criar ZIP extraindo as classes do JAR shaded
echo "🗜️  Criando lambda-auth.zip..."
cd target

# Criar diretório temporário para extração
mkdir -p lambda-temp
cd lambda-temp

# Extrair o JAR shaded
echo "📤 Extraindo JAR shaded..."
jar -xf "../$(basename "$JAR_FILE")"

# Criar ZIP com as classes extraídas
echo "📦 Criando ZIP com classes..."
zip -r ../../lambda-auth.zip . -x "META-INF/MANIFEST.MF"

# Limpar diretório temporário
cd ..
rm -rf lambda-temp
cd ..

# Verificar se o ZIP foi criado
if [ -f "lambda-auth.zip" ]; then
    FILE_SIZE=$(ls -lh lambda-auth.zip | awk '{print $5}')
    echo "✅ lambda-auth.zip criado com sucesso! (${FILE_SIZE})"
    echo ""
    echo "📋 Próximo passo:"
    echo "   Execute o Terraform para fazer deploy da Lambda"
else
    echo "❌ Erro ao criar lambda-auth.zip"
    exit 1
fi