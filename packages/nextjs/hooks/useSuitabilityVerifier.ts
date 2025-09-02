import { SuitabilityResult } from "~~/types/suitability";

export const useSuitabilityVerifier = () => {
  // Função para calcular o perfil de risco baseado nas respostas
  const calculateRiskProfile = (answers: number[]): SuitabilityResult => {
    const weights = [3, 3, 2, 2, 1]; // Pesos das 5 perguntas
    const totalScore = answers.reduce((sum, answer, index) => sum + answer * weights[index], 0);
    const maxPossibleScore = 3 * weights.reduce((a, b) => a + b, 0); // 3 * 11 = 33

    // Normalizar para 0-15
    const riskProfile = Math.floor((totalScore * 15) / maxPossibleScore);

    // Determinar nível de risco
    let riskLevel: "conservador" | "moderado" | "sofisticado";
    if (riskProfile <= 5) {
      riskLevel = "conservador";
    } else if (riskProfile <= 10) {
      riskLevel = "moderado";
    } else {
      riskLevel = "sofisticado";
    }

    // Por enquanto, consideramos adequado se o perfil for >= 3
    const isSuitable = riskProfile >= 3;

    return {
      riskProfile,
      riskLevel,
      isSuitable,
      answers,
      totalScore,
    };
  };

  // Função para obter as perguntas do questionário
  const getQuestions = () => {
    return [
      {
        id: 1,
        text: "Qual é sua experiência com investimentos?",
        options: [
          "Nenhuma experiência (0)",
          "Pouca experiência (1)",
          "Experiência moderada (2)",
          "Muita experiência (3)",
        ],
        weight: 3,
      },
      {
        id: 2,
        text: "Como você descreveria sua tolerância ao risco?",
        options: ["Muito conservador (0)", "Conservador (1)", "Moderado (2)", "Agressivo (3)"],
        weight: 3,
      },
      {
        id: 3,
        text: "Qual é seu horizonte temporal para investimentos?",
        options: [
          "Curto prazo < 1 ano (0)",
          "Médio prazo 1-5 anos (1)",
          "Longo prazo 5-10 anos (2)",
          "Muito longo prazo > 10 anos (3)",
        ],
        weight: 2,
      },
      {
        id: 4,
        text: "Qual é seu principal objetivo financeiro?",
        options: [
          "Preservar capital (0)",
          "Renda regular (1)",
          "Crescimento moderado (2)",
          "Crescimento agressivo (3)",
        ],
        weight: 2,
      },
      {
        id: 5,
        text: "Como você avalia seu conhecimento do mercado financeiro?",
        options: ["Iniciante (0)", "Básico (1)", "Intermediário (2)", "Avançado (3)"],
        weight: 1,
      },
    ];
  };

  return {
    calculateRiskProfile,
    getQuestions,
  };
};
