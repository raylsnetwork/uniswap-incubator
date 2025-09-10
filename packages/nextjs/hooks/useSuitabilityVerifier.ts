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
    let riskLevel: "conservative" | "moderate" | "sophisticated";
    if (riskProfile <= 5) {
      riskLevel = "conservative";
    } else if (riskProfile <= 10) {
      riskLevel = "moderate";
    } else {
      riskLevel = "sophisticated";
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
        text: "What is your investment experience?",
        options: ["No experience (0)", "Little experience (1)", "Moderate experience (2)", "Extensive experience (3)"],
        weight: 3,
      },
      {
        id: 2,
        text: "How would you describe your risk tolerance?",
        options: ["Very conservative (0)", "Conservative (1)", "Moderate (2)", "Aggressive (3)"],
        weight: 3,
      },
      {
        id: 3,
        text: "What is your investment time horizon?",
        options: [
          "Short term < 1 year (0)",
          "Medium term 1-5 years (1)",
          "Long term 5-10 years (2)",
          "Very long term > 10 years (3)",
        ],
        weight: 2,
      },
      {
        id: 4,
        text: "What is your main financial objective?",
        options: ["Preserve capital (0)", "Regular income (1)", "Moderate growth (2)", "Aggressive growth (3)"],
        weight: 2,
      },
      {
        id: 5,
        text: "How do you rate your knowledge of the financial market?",
        options: ["Beginner (0)", "Basic (1)", "Intermediate (2)", "Advanced (3)"],
        weight: 1,
      },
    ];
  };

  return {
    calculateRiskProfile,
    getQuestions,
  };
};
