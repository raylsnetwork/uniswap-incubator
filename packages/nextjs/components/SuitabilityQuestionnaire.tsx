"use client";

import { useState } from "react";
import { useSuitabilityVerifier } from "~~/hooks/useSuitabilityVerifier";
import { SuitabilityResult } from "~~/types/suitability";

export const SuitabilityQuestionnaire = () => {
  const [answers, setAnswers] = useState<number[]>([-1, -1, -1, -1, -1]); // -1 indica não respondido
  const [currentStep, setCurrentStep] = useState<number>(0);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [result, setResult] = useState<SuitabilityResult | null>(null);
  const [showResult, setShowResult] = useState(false);

  const { calculateRiskProfile, getQuestions } = useSuitabilityVerifier();
  const questions = getQuestions();

  const handleAnswerChange = (questionIndex: number, value: number) => {
    const newAnswers = [...answers];
    newAnswers[questionIndex] = value;
    setAnswers(newAnswers);
  };

  const nextStep = () => {
    if (currentStep < questions.length - 1) {
      setCurrentStep(currentStep + 1);
    }
  };

  const prevStep = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };

  const isAllAnswered = () => {
    return answers.every(answer => answer !== -1);
  };

  const handleSubmit = async () => {
    if (!isAllAnswered()) {
      alert("Por favor, responda todas as perguntas antes de continuar.");
      return;
    }

    setIsSubmitting(true);
    try {
      const result = calculateRiskProfile(answers);
      setResult(result);
      setShowResult(true);
    } catch (error) {
      console.error("Erro ao processar questionário:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const resetQuestionnaire = () => {
    setAnswers([-1, -1, -1, -1, -1]);
    setCurrentStep(0);
    setResult(null);
    setShowResult(false);
  };

  const getProgressPercentage = () => {
    const answered = answers.filter(answer => answer !== -1).length;
    return (answered / questions.length) * 100;
  };

  const getRiskLevelColor = (level: string) => {
    switch (level) {
      case "conservador":
        return "text-green-600 bg-green-50 border-green-200";
      case "moderado":
        return "text-yellow-600 bg-yellow-50 border-yellow-200";
      case "sofisticado":
        return "text-red-600 bg-red-50 border-red-200";
      default:
        return "text-gray-600 bg-gray-50 border-gray-200";
    }
  };

  if (showResult && result) {
    return (
      <div className="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-lg">
        <div className="text-center mb-6">
          <h2 className="text-3xl font-bold mb-4 text-gray-900">Resultado do Questionário</h2>
          <div className={`inline-block px-6 py-3 rounded-full border-2 ${getRiskLevelColor(result.riskLevel)}`}>
            <span className="text-lg font-semibold capitalize">{result.riskLevel}</span>
          </div>
        </div>

        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="bg-gray-50 p-4 rounded-lg">
              <h3 className="font-semibold text-gray-700 mb-2">Perfil de Risco</h3>
              <p className="text-2xl font-bold text-gray-900">{result.riskProfile}/15</p>
            </div>
            <div className="bg-gray-50 p-4 rounded-lg">
              <h3 className="font-semibold text-gray-700 mb-2">Pontuação Total</h3>
              <p className="text-2xl font-bold text-gray-900">{result.totalScore}/33</p>
            </div>
          </div>

          <div
            className={`p-4 rounded-lg border-2 ${result.isSuitable ? "bg-green-50 border-green-200" : "bg-red-50 border-red-200"}`}
          >
            <h3 className="font-semibold mb-2 text-gray-900">
              {result.isSuitable ? "✅ Perfil Adequado" : "❌ Perfil Inadequado"}
            </h3>
            <p className="text-sm text-gray-700">
              {result.isSuitable
                ? "Você pode prosseguir com investimentos de risco moderado a alto."
                : "Recomendamos investimentos de baixo risco ou consultar um especialista."}
            </p>
          </div>

          <div className="bg-blue-50 p-4 rounded-lg">
            <h3 className="font-semibold text-blue-800 mb-2">Suas Respostas</h3>
            <div className="space-y-2">
              {questions.map((question, index) => (
                <div key={question.id} className="text-sm">
                  <span className="font-medium text-gray-900">
                    {question.id}. {question.text}
                  </span>
                  <span className="text-blue-600 ml-2">→ {question.options[answers[index]]}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="flex gap-4">
            <button
              onClick={resetQuestionnaire}
              className="flex-1 bg-gray-600 text-white py-3 px-6 rounded-lg hover:bg-gray-700 transition-colors"
            >
              Refazer Questionário
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-lg">
      <div className="text-center mb-6">
        <h2 className="text-3xl font-bold mb-2 text-gray-900">Questionário de Suitability</h2>
        <p className="text-gray-700">Avalie seu perfil de investidor em 5 perguntas</p>
      </div>

      {/* Progress Bar */}
      <div className="mb-6">
        <div className="flex justify-between text-sm text-gray-600 mb-2">
          <span>Progresso</span>
          <span>{Math.round(getProgressPercentage())}%</span>
        </div>
        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className="bg-blue-600 h-2 rounded-full transition-all duration-300"
            style={{ width: `${getProgressPercentage()}%` }}
          ></div>
        </div>
      </div>

      {/* Current Question */}
      <div className="mb-6">
        <div className="text-sm text-gray-500 mb-2">
          Pergunta {currentStep + 1} de {questions.length}
        </div>
        <h3 className="text-xl font-semibold mb-4 text-gray-900">{questions[currentStep].text}</h3>

        <div className="space-y-3">
          {questions[currentStep].options.map((option, optionIndex) => (
            <label
              key={optionIndex}
              className={`flex items-center p-4 border-2 rounded-lg cursor-pointer transition-all hover:bg-gray-50 ${
                answers[currentStep] === optionIndex ? "border-blue-500 bg-blue-50" : "border-gray-200"
              }`}
            >
              <input
                type="radio"
                name={`question-${questions[currentStep].id}`}
                value={optionIndex}
                checked={answers[currentStep] === optionIndex}
                onChange={e => handleAnswerChange(currentStep, parseInt(e.target.value))}
                className="sr-only"
              />
              <div
                className={`w-4 h-4 rounded-full border-2 mr-3 flex items-center justify-center ${
                  answers[currentStep] === optionIndex ? "border-blue-500 bg-blue-500" : "border-gray-300"
                }`}
              >
                {answers[currentStep] === optionIndex && <div className="w-2 h-2 rounded-full bg-white"></div>}
              </div>
              <span className="text-sm text-gray-900">{option}</span>
            </label>
          ))}
        </div>
      </div>

      {/* Navigation */}
      <div className="flex justify-between">
        <button
          onClick={prevStep}
          disabled={currentStep === 0}
          className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed text-gray-700"
        >
          Anterior
        </button>

        <div className="flex gap-2">
          {currentStep < questions.length - 1 ? (
            <button
              onClick={nextStep}
              disabled={answers[currentStep] === -1}
              className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Próxima
            </button>
          ) : (
            <button
              onClick={handleSubmit}
              disabled={!isAllAnswered() || isSubmitting}
              className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? "Processando..." : "Verificar Suitability"}
            </button>
          )}
        </div>
      </div>

      {/* Question Navigation Dots */}
      <div className="flex justify-center mt-6 space-x-2">
        {questions.map((_, index) => (
          <button
            key={index}
            onClick={() => setCurrentStep(index)}
            className={`w-3 h-3 rounded-full transition-all ${
              index === currentStep ? "bg-blue-600" : answers[index] !== -1 ? "bg-green-400" : "bg-gray-300"
            }`}
          />
        ))}
      </div>
    </div>
  );
};
