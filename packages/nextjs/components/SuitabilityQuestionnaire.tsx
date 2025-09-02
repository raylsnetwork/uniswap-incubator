
"use client";

import { useState } from "react";
import { useSuitabilityVerifier } from "~~/hooks/useSuitabilityVerifier";

interface Question {
    id: number;
    text: string;
    options: string[];
    weight: number;
}

const questions: Question[] = [
    {
        id: 1,
        text: "Qual é sua experiência com investimentos?",
        options: [
            "Nenhuma experiência",
            "Pouca experiência",
            "Experiência moderada",
            "Muita experiência"
        ],
        weight: 2
    },
    {
        id: 2,
        text: "Como você descreveria sua tolerância ao risco?",
        options: [
            "Muito conservador",
            "Conservador",
            "Moderado",
            "Agressivo"
        ],
        weight: 3
    },
    {
        id: 3,
        text: "Qual é seu horizonte temporal para investimentos?",
        options: [
            "Curto prazo (< 1 ano)",
            "Médio prazo (1-5 anos)",
            "Longo prazo (5-10 anos)",
            "Muito longo prazo (> 10 anos)"
        ],
        weight: 2
    },
    {
        id: 4,
        text: "Qual é seu principal objetivo financeiro?",
        options: [
            "Preservar capital",
            "Renda regular",
            "Crescimento moderado",
            "Crescimento agressivo"
        ],
        weight: 1
    },
    {
        id: 5,
        text: "Como você avalia seu conhecimento do mercado financeiro?",
        options: [
            "Iniciante",
            "Básico",
            "Intermediário",
            "Avançado"
        ],
        weight: 2
    }
];

export const SuitabilityQuestionnaire = () => {
    const [answers, setAnswers] = useState<number[]>([0, 0, 0, 0, 0]);
    const [threshold, setThreshold] = useState<number>(5);
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [result, setResult] = useState<{ riskProfile: number; isSuitable: boolean } | null>(null);
    
    const { verifySuitability } = useSuitabilityVerifier();
    
    const handleAnswerChange = (questionIndex: number, value: number) => {
        const newAnswers = [...answers];
        newAnswers[questionIndex] = value;
        setAnswers(newAnswers);
    };
    
    const calculateRiskProfile = (answers: number[]) => {
        const weights = [2, 3, 2, 1, 2];
        const weightedSum = answers.reduce((sum, answer, index) => sum + answer * weights[index], 0);
        const maxPossibleScore = 4 * weights.reduce((a, b) => a + b, 0);
        return Math.floor((weightedSum * 10) / maxPossibleScore);
    };
    
    const handleSubmit = async () => {
        setIsSubmitting(true);
        try {
            const riskProfile = calculateRiskProfile(answers);
            const isSuitable = riskProfile >= threshold;
            
            // Em um cenário real, aqui você geraria a prova ZK
            // Por enquanto, apenas simulamos o resultado
            setResult({ riskProfile, isSuitable });
            
            console.log("Perfil de risco:", riskProfile);
            console.log("É adequado?", isSuitable);
            
        } catch (error) {
            console.error("Erro ao processar questionário:", error);
        } finally {
            setIsSubmitting(false);
        }
    };
    
    return (
        <div className="max-w-2xl mx-auto p-6 bg-white rounded-lg shadow-lg">
            <h2 className="text-2xl font-bold mb-6 text-center">Questionário de Suitability</h2>
            
            <div className="space-y-6">
                {questions.map((question, index) => (
                    <div key={question.id} className="border rounded-lg p-4">
                        <h3 className="text-lg font-semibold mb-3">
                            {question.id}. {question.text}
                        </h3>
                        <div className="space-y-2">
                            {question.options.map((option, optionIndex) => (
                                <label key={optionIndex} className="flex items-center space-x-2">
                                    <input
                                        type="radio"
                                        name={`question-${question.id}`}
                                        value={optionIndex}
                                        checked={answers[index] === optionIndex}
                                        onChange={(e) => handleAnswerChange(index, parseInt(e.target.value))}
                                        className="text-blue-600"
                                    />
                                    <span>{option}</span>
                                </label>
                            ))}
                        </div>
                    </div>
                ))}
                
                <div className="border rounded-lg p-4">
                    <label className="block text-lg font-semibold mb-3">
                        Threshold mínimo de risco (0-10):
                    </label>
                    <input
                        type="range"
                        min="0"
                        max="10"
                        value={threshold}
                        onChange={(e) => setThreshold(parseInt(e.target.value))}
                        className="w-full"
                    />
                    <span className="text-sm text-gray-600">Threshold: {threshold}</span>
                </div>
                
                <button
                    onClick={handleSubmit}
                    disabled={isSubmitting}
                    className="w-full bg-blue-600 text-white py-3 px-6 rounded-lg hover:bg-blue-700 disabled:opacity-50"
                >
                    {isSubmitting ? "Processando..." : "Verificar Suitability"}
                </button>
                
                {result && (
                    <div className={`border rounded-lg p-4 ${result.isSuitable ? 'bg-green-50' : 'bg-red-50'}`}>
                        <h3 className="text-lg font-semibold mb-2">
                            {result.isSuitable ? "✅ Perfil Adequado" : "❌ Perfil Inadequado"}
                        </h3>
                        <p>Perfil de risco: {result.riskProfile}/10</p>
                        <p>Threshold mínimo: {threshold}/10</p>
                        {result.isSuitable && (
                            <p className="text-green-700 font-semibold">
                                Você pode prosseguir com investimentos de risco {threshold}+
                            </p>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
};
