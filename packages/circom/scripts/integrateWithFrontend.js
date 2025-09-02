const fs = require("fs");
const path = require("path");

// Função para gerar tipos TypeScript para o contrato
function generateContractTypes() {
    console.log("📝 Gerando tipos TypeScript para o contrato...");
    
    const contractTypes = `
// Tipos para o contrato SuitabilityVerifier
export interface Proof {
    a: [string, string];
    b: [[string, string], [string, string]];
    c: [string, string];
}

export interface PublicInputs {
    threshold: string;
    riskProfile: string;
    isSuitable: string;
}

export interface SuitabilityVerifierContract {
    verifySuitability: (proof: Proof, publicInputs: PublicInputs) => Promise<boolean>;
    isUserSuitable: (user: string) => Promise<boolean>;
    revokeSuitability: (user: string) => Promise<void>;
    getVerificationCount: () => Promise<string>;
}
`;
    
    const typesPath = path.join(__dirname, "../../nextjs/types/suitability.ts");
    fs.writeFileSync(typesPath, contractTypes);
    
    console.log("✅ Tipos TypeScript gerados em:", typesPath);
}

// Função para gerar hook personalizado para suitability
function generateSuitabilityHook() {
    console.log("🔧 Gerando hook personalizado para suitability...");
    
    const hookCode = `
import { useScaffoldWriteContract, useScaffoldReadContract } from "~~/hooks/scaffold-eth";
import { Proof, PublicInputs } from "~~/types/suitability";

export const useSuitabilityVerifier = () => {
    const { writeContractAsync: verifySuitabilityAsync } = useScaffoldWriteContract({
        contractName: "SuitabilityVerifier"
    });
    
    const { data: isUserSuitable } = useScaffoldReadContract({
        contractName: "SuitabilityVerifier",
        functionName: "isUserSuitable",
        args: [undefined] // será preenchido dinamicamente
    });
    
    const { data: verificationCount } = useScaffoldReadContract({
        contractName: "SuitabilityVerifier",
        functionName: "getVerificationCount"
    });
    
    const verifySuitability = async (proof: Proof, publicInputs: PublicInputs) => {
        try {
            const result = await verifySuitabilityAsync({
                functionName: "verifySuitability",
                args: [proof, publicInputs]
            });
            return result;
        } catch (error) {
            console.error("Erro ao verificar suitability:", error);
            throw error;
        }
    };
    
    const checkUserSuitability = async (userAddress: string) => {
        try {
            const result = await useScaffoldReadContract({
                contractName: "SuitabilityVerifier",
                functionName: "isUserSuitable",
                args: [userAddress]
            });
            return result;
        } catch (error) {
            console.error("Erro ao verificar suitability do usuário:", error);
            throw error;
        }
    };
    
    return {
        verifySuitability,
        checkUserSuitability,
        isUserSuitable,
        verificationCount
    };
};
`;
    
    const hookPath = path.join(__dirname, "../../nextjs/hooks/useSuitabilityVerifier.ts");
    fs.writeFileSync(hookPath, hookCode);
    
    console.log("✅ Hook personalizado gerado em:", hookPath);
}

// Função para gerar componente de questionário
function generateQuestionnaireComponent() {
    console.log("🎨 Gerando componente de questionário...");
    
    const componentCode = `
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
                                        name={\`question-\${question.id}\`}
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
                    <div className={\`border rounded-lg p-4 \${result.isSuitable ? 'bg-green-50' : 'bg-red-50'}\`}>
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
`;
    
    const componentPath = path.join(__dirname, "../../nextjs/components/SuitabilityQuestionnaire.tsx");
    fs.writeFileSync(componentPath, componentCode);
    
    console.log("✅ Componente de questionário gerado em:", componentPath);
}

// Função para atualizar deployedContracts.ts
function updateDeployedContracts() {
    console.log("📝 Atualizando deployedContracts.ts...");
    
    const deployedContractsPath = path.join(__dirname, "../../nextjs/contracts/deployedContracts.ts");
    
    // Verificar se o arquivo existe
    if (!fs.existsSync(deployedContractsPath)) {
        console.log("⚠️  Arquivo deployedContracts.ts não encontrado");
        return;
    }
    
    let content = fs.readFileSync(deployedContractsPath, 'utf8');
    
    // Adicionar SuitabilityVerifier se não existir
    if (!content.includes("SuitabilityVerifier")) {
        const suitabilityContract = `
  SuitabilityVerifier: {
    address: "0x0000000000000000000000000000000000000000", // Substitua pelo endereço real
    abi: [
      // ABI será gerado automaticamente pelo Foundry
    ] as const,
  },
`;
        
        // Inserir antes do fechamento do objeto
        const insertIndex = content.lastIndexOf("}");
        content = content.slice(0, insertIndex) + suitabilityContract + content.slice(insertIndex);
        
        fs.writeFileSync(deployedContractsPath, content);
        console.log("✅ SuitabilityVerifier adicionado ao deployedContracts.ts");
    } else {
        console.log("ℹ️  SuitabilityVerifier já existe no deployedContracts.ts");
    }
}

// Função principal
function main() {
    console.log("🔗 Integrando sistema ZK com frontend...");
    
    try {
        // Gerar tipos TypeScript
        generateContractTypes();
        
        // Gerar hook personalizado
        generateSuitabilityHook();
        
        // Gerar componente de questionário
        generateQuestionnaireComponent();
        
        // Atualizar deployedContracts.ts
        updateDeployedContracts();
        
        console.log("\n🎉 Integração concluída!");
        console.log("\n📋 Próximos passos:");
        console.log("1. Deploy do contrato: cd ../foundry && forge script script/DeploySuitabilityVerifier.s.sol --rpc-url http://localhost:8545 --broadcast");
        console.log("2. Atualizar endereço do contrato em deployedContracts.ts");
        console.log("3. Adicionar componente ao frontend: import SuitabilityQuestionnaire from '~/components/SuitabilityQuestionnaire'");
        console.log("4. Testar integração completa");
        
    } catch (error) {
        console.error("❌ Erro durante integração:", error.message);
        process.exit(1);
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    main();
}

module.exports = {
    generateContractTypes,
    generateSuitabilityHook,
    generateQuestionnaireComponent,
    updateDeployedContracts,
    main
};
