# Questionário de Suitability

Este é um questionário de adequação (suitability) para avaliar o perfil de risco de investidores. O questionário foi desenvolvido seguindo diretrizes regulatórias e boas práticas do mercado financeiro.

## Características

### Estrutura do Questionário
- **5 perguntas** principais sobre perfil de investidor
- **4 opções** de resposta para cada pergunta (valores de 0 a 3)
- **Sistema de pesos** para diferentes perguntas
- **Navegação por etapas** com barra de progresso
- **Resultado detalhado** com classificação de risco

### Perguntas do Questionário

1. **Experiência com Investimentos** (Peso: 3)
   - Nenhuma experiência (0)
   - Pouca experiência (1)
   - Experiência moderada (2)
   - Muita experiência (3)

2. **Tolerância ao Risco** (Peso: 3)
   - Muito conservador (0)
   - Conservador (1)
   - Moderado (2)
   - Agressivo (3)

3. **Horizonte Temporal** (Peso: 2)
   - Curto prazo < 1 ano (0)
   - Médio prazo 1-5 anos (1)
   - Longo prazo 5-10 anos (2)
   - Muito longo prazo > 10 anos (3)

4. **Objetivo Financeiro** (Peso: 2)
   - Preservar capital (0)
   - Renda regular (1)
   - Crescimento moderado (2)
   - Crescimento agressivo (3)

5. **Conhecimento do Mercado** (Peso: 1)
   - Iniciante (0)
   - Básico (1)
   - Intermediário (2)
   - Avançado (3)

### Cálculo do Perfil de Risco

- **Pontuação Total Máxima**: 33 pontos (3×3 + 3×3 + 2×3 + 2×3 + 1×3)
- **Perfil Normalizado**: 0-15 pontos
- **Classificação de Risco**:
  - 0-5: Conservador
  - 6-10: Moderado
  - 11-15: Sofisticado

### Critério de Adequação

- **Adequado**: Perfil ≥ 3 pontos
- **Inadequado**: Perfil < 3 pontos

## Tecnologias Utilizadas

- **Frontend**: Next.js 15 com TypeScript
- **UI**: Tailwind CSS + DaisyUI
- **Estado**: React Hooks
- **Navegação**: Next.js App Router

## Estrutura de Arquivos

```
packages/nextjs/
├── app/
│   └── suitability/
│       └── page.tsx              # Página do questionário
├── components/
│   └── SuitabilityQuestionnaire.tsx  # Componente principal
├── hooks/
│   └── useSuitabilityVerifier.ts     # Hook com lógica de cálculo
└── types/
    └── suitability.ts                # Tipos TypeScript
```

## Como Usar

1. **Acesse a página**: `http://localhost:3000/suitability`
2. **Responda as perguntas**: Navegue pelas 5 perguntas
3. **Visualize o resultado**: Veja seu perfil de risco e adequação
4. **Refaça se necessário**: Use o botão "Refazer Questionário"

## Funcionalidades

### Interface do Usuário
- ✅ Navegação por etapas
- ✅ Barra de progresso
- ✅ Indicadores visuais de progresso
- ✅ Design responsivo
- ✅ Feedback visual das seleções

### Resultados
- ✅ Perfil de risco (0-15)
- ✅ Classificação (Conservador/Moderado/Sofisticado)
- ✅ Pontuação total
- ✅ Status de adequação
- ✅ Resumo das respostas

### Experiência do Usuário
- ✅ Validação de respostas
- ✅ Navegação intuitiva
- ✅ Feedback imediato
- ✅ Possibilidade de refazer

## Próximos Passos

1. **Integração com Smart Contract**: Conectar com o contrato SuitabilityVerifier
2. **Provas ZK**: Implementar geração de provas zero-knowledge
3. **Persistência**: Salvar resultados no blockchain
4. **Histórico**: Manter histórico de avaliações
5. **Relatórios**: Gerar relatórios detalhados

## Desenvolvimento

### Executar Localmente
```bash
cd packages/nextjs
yarn dev
```

### Build de Produção
```bash
cd packages/nextjs
yarn build
```

### Testes
```bash
cd packages/nextjs
yarn test
```

## Contribuição

Para contribuir com melhorias no questionário:

1. Mantenha a estrutura de 5 perguntas
2. Preserve o sistema de pesos
3. Teste a responsividade
4. Valide a acessibilidade
5. Documente mudanças

## Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.
