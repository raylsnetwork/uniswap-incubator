# Suitability Assessment com Zero-Knowledge Proofs

Este projeto implementa um sistema de avaliação de suitability (adequação) de investidores usando Zero-Knowledge Proofs (ZKP) com Circom e SnarkJS. O sistema permite que um usuário prove que possui um perfil de risco adequado sem revelar suas respostas específicas do questionário.

## 🎯 Objetivo

O objetivo é criar um sistema onde:
- Um usuário responde a 5 perguntas de suitability
- Cada resposta tem um peso específico
- O sistema calcula um perfil de risco (0-10)
- O usuário pode provar que seu perfil atende a um threshold mínimo
- **Sem revelar suas respostas específicas**

## 🏗️ Arquitetura

### Circuito Circom (`circuits/SuitabilityAssessment.circom`)

O circuito implementa a lógica de:
- **Entradas privadas**: 5 respostas do questionário (0-3 cada)
- **Entradas públicas**: threshold mínimo e perfil de risco calculado
- **Saída pública**: indica se o perfil atende ao threshold (0 ou 1)

### Pesos das Perguntas

| Pergunta | Peso | Descrição |
|----------|------|-----------|
| 1 | 2 | Experiência de investimento |
| 2 | 3 | Tolerância ao risco |
| 3 | 2 | Horizonte temporal |
| 4 | 1 | Objetivos financeiros |
| 5 | 2 | Conhecimento do mercado |

### Cálculo do Perfil de Risco

```
weightedSum = answer1*2 + answer2*3 + answer3*2 + answer4*1 + answer5*2
maxPossibleScore = 4 * (2+3+2+1+2) = 40
riskProfile = (weightedSum * 10) / maxPossibleScore
```

## 🚀 Instalação e Configuração

### Pré-requisitos

```bash
# Instalar dependências globais
npm install -g circom snarkjs

# Instalar dependências do projeto
yarn install
```

### Setup Inicial

1. **Compilar o circuito**:
```bash
yarn compile
```

2. **Configurar Powers of Tau e chaves ZK**:
```bash
yarn setup
```

3. **Executar testes**:
```bash
yarn test
```

## 📋 Fluxo de Trabalho

### 1. Compilação do Circuito

```bash
yarn compile
```

```bash
circom SuitabilityAssessment.circom --r1cs --wasm --sym --c -l "/Volumes/Lucas SSD/projects/uhi6"
```

Gera:
- `circuits/SuitabilityAssessment.r1cs` - Constraints do circuito
- `circuits/SuitabilityAssessment_js/` - Código JavaScript para cálculo de witness
- `circuits/SuitabilityAssessment.sym` - Símbolos do circuito

### 2. Setup das Chaves ZK

```bash
yarn setup
```

Este comando executa:
- Geração do Powers of Tau (Fase 1)
- Contribuições para Powers of Tau
- Finalização do Powers of Tau
- Preparação da Fase 2
- Setup do circuito Groth16
- Contribuições para ZKey
- Exportação da chave de verificação

### 3. Geração de Provas

```bash
yarn generate-proof
```

Gera:
- `scripts/input.json` - Dados de entrada de exemplo
- `scripts/witness.wtns` - Witness do circuito
- `scripts/proof.json` - Prova ZK
- `scripts/public.json` - Dados públicos

### 4. Verificação de Provas

```bash
yarn verify-proof
```

Verifica se a prova é válida usando a chave de verificação.

## 🔧 Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `yarn compile` | Compila o circuito Circom |
| `yarn setup` | Setup completo das chaves ZK |
| `yarn contribute` | Contribui para ZKey |
| `yarn export-verifier` | Exporta chave de verificação |
| `yarn generate-proof` | Gera prova ZK de exemplo |
| `yarn verify-proof` | Verifica prova ZK |
| `yarn test` | Executa testes do sistema |

## 🧪 Testes

O sistema inclui testes abrangentes:

```bash
yarn test
```

Testa cenários como:
- Perfil de baixo risco
- Perfil de médio risco
- Perfil de alto risco
- Thresholds diferentes
- Validação de constraints

## 📊 Exemplos de Uso

### Exemplo 1: Perfil Adequado

```javascript
// Respostas do usuário
const answers = [2, 3, 1, 2, 3]; // Perfil de médio-alto risco
const threshold = 6; // Threshold mínimo

// Resultado esperado
// riskProfile = 7 (adequado)
// isSuitable = 1 (true)
```

### Exemplo 2: Perfil Inadequado

```javascript
// Respostas do usuário
const answers = [0, 1, 0, 1, 0]; // Perfil de baixo risco
const threshold = 6; // Threshold mínimo

// Resultado esperado
// riskProfile = 3 (inadequado)
// isSuitable = 0 (false)
```

## 🔐 Contrato Solidity

O contrato `contracts/SuitabilityVerifier.sol` permite:

- Verificar provas ZK on-chain
- Armazenar status de suitability por endereço
- Revogar suitability (apenas owner)
- Rastrear verificações

### Funções Principais

```solidity
function verifySuitability(Proof calldata proof, PublicInputs calldata publicInputs) external returns (bool)
function isUserSuitable(address user) external view returns (bool)
function revokeSuitability(address user) external onlyOwner
```

## 🛡️ Segurança

### Privacidade
- **Respostas privadas**: Nunca reveladas
- **Perfil calculado**: Pode ser público
- **Threshold**: Pode ser público
- **Resultado**: Pode ser público

### Validação
- Constraints garantem respostas válidas (0-3)
- Verificação de consistência entre perfil e threshold
- Validação de limites (0-10)

## 🔄 Integração com Scaffold-ETH 2

Para integrar com o frontend:

1. **Deploy do contrato**:
```bash
cd ../foundry
forge build
forge script script/DeploySuitabilityVerifier.s.sol --rpc-url http://localhost:8545 --broadcast
```

2. **Atualizar deployedContracts.ts**:
```typescript
export const deployedContracts = {
  // ... outros contratos
  SuitabilityVerifier: {
    // endereço do contrato deployado
  }
};
```

3. **Usar hooks do Scaffold-ETH**:
```typescript
const { writeContractAsync: verifySuitabilityAsync } = useScaffoldWriteContract({
  contractName: "SuitabilityVerifier"
});

// Verificar suitability
await verifySuitabilityAsync({
  functionName: "verifySuitability",
  args: [proof, publicInputs]
});
```

## 📈 Próximos Passos

1. **Implementação completa da verificação on-chain**
2. **Interface de usuário para questionário**
3. **Sistema de credenciais verificáveis**
4. **Integração com provedores de KYC**
5. **Auditoria de segurança**

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📄 Licença

MIT License - veja o arquivo [LICENSE](../LICENSE) para detalhes.

## 🆘 Suporte

Para dúvidas ou problemas:
1. Verifique a documentação
2. Execute os testes
3. Abra uma issue no GitHub

---

**Nota**: Este é um projeto educacional. Para uso em produção, considere auditorias de segurança e implementações mais robustas.
