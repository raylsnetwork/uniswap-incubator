"use client";

import { SuitabilityQuestionnaire } from "~~/components/SuitabilityQuestionnaire";

const SuitabilityPage = () => {
  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="container mx-auto px-4">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Suitability Assessment</h1>
          <p className="text-lg text-gray-700 max-w-2xl mx-auto">
            This questionnaire evaluates your investor profile to determine your suitability for different types of
            investments. Your responses are confidential and used only for suitability purposes.
          </p>
        </div>

        <SuitabilityQuestionnaire />

        <div className="mt-8 text-center text-sm text-gray-600">
          <p>
            This assessment is based on regulatory guidelines and does not constitute investment advice. Always consult
            a qualified professional.
          </p>
        </div>
      </div>
    </div>
  );
};

export default SuitabilityPage;
