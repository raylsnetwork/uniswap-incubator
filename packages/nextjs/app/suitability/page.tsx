"use client";

import { SuitabilityQuestionnaire } from "~~/components/SuitabilityQuestionnaire";

const SuitabilityPage = () => {
  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="container mx-auto px-4">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Avaliação de Suitability</h1>
          <p className="text-lg text-gray-700 max-w-2xl mx-auto">
            Este questionário avalia seu perfil de investidor para determinar sua adequação a diferentes tipos de
            investimentos. Suas respostas são confidenciais e usadas apenas para fins de adequação.
          </p>
        </div>

        <SuitabilityQuestionnaire />

        <div className="mt-8 text-center text-sm text-gray-600">
          <p>
            Esta avaliação é baseada em diretrizes regulatórias e não constitui recomendação de investimento. Consulte
            sempre um profissional qualificado.
          </p>
        </div>
      </div>
    </div>
  );
};

export default SuitabilityPage;
