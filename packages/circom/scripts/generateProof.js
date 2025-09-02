const fs = require("fs");
const path = require("path");

// Função para gerar prova ZK
async function generateProof() {
    try {
        console.log("🚀 Iniciando geração de prova ZK...");
        
        // Verificar se os arquivos necessários existem
        const zkeyPath = path.join(__dirname, "../SuitabilityAssessment_final_new.zkey");
        const wasmPath = path.join(__dirname, "../SuitabilityAssessment_js/SuitabilityAssessment.wasm");
        
        if (!fs.existsSync(zkeyPath)) {
            throw new Error("Arquivo .zkey não encontrado. Execute 'yarn setup' e 'yarn contribute' primeiro.");
        }
        
        if (!fs.existsSync(wasmPath)) {
            throw new Error("Arquivo .wasm não encontrado. Execute 'yarn compile' primeiro.");
        }
        
        // Exemplo de dados de entrada
        const input = {
            answer1: 3, // Resposta da pergunta 1 (0-3)
            answer2: 2, // Resposta da pergunta 2 (0-3)
            answer3: 1, // Resposta da pergunta 3 (0-3)
            answer4: 2, // Resposta da pergunta 4 (0-3)
            answer5: 3, // Resposta da pergunta 5 (0-3)
            threshold: 5  // Threshold mínimo de risco
        };
        
        console.log("📝 Dados de entrada:", input);
        
        // Calcular o perfil de risco esperado para verificação
        const weights = [2, 3, 2, 1, 2];
        const weightedSum = input.answer1 * weights[0] + 
                           input.answer2 * weights[1] + 
                           input.answer3 * weights[2] + 
                           input.answer4 * weights[3] + 
                           input.answer5 * weights[4];
        
        const maxPossibleScore = 4 * weights.reduce((a, b) => a + b, 0);
        const expectedRiskProfile = Math.floor((weightedSum * 10) / maxPossibleScore);
        const expectedIsSuitable = expectedRiskProfile >= input.threshold ? 1 : 0;
        
        console.log("📊 Perfil de risco esperado:", expectedRiskProfile);
        console.log("✅ É adequado?", expectedIsSuitable ? "Sim" : "Não");
        
        // Salvar dados de entrada para uso com SnarkJS
        const inputPath = path.join(__dirname, "input.json");
        fs.writeFileSync(inputPath, JSON.stringify(input, null, 2));
        
        console.log("💾 Dados de entrada salvos em:", inputPath);
        console.log("\n📋 Próximos passos:");
        console.log("1. Execute: /opt/homebrew/bin/snarkjs groth16 prove circuits/SuitabilityAssessment_final.zkey input.json proof.json public.json");
        console.log("2. Execute: /opt/homebrew/bin/snarkjs groth16 verify circuits/verification_key.json public.json proof.json");
        
    } catch (error) {
        console.error("❌ Erro ao gerar prova:", error.message);
        process.exit(1);
    }
}

// Função para calcular witness
async function calculateWitness() {
    try {
        console.log("🧮 Calculando witness...");
        
        const { execSync } = require("child_process");
        const wasmPath = path.join(__dirname, "../SuitabilityAssessment_js/SuitabilityAssessment.wasm");
        const inputPath = path.join(__dirname, "input.json");
        const witnessPath = path.join(__dirname, "witness.wtns");
        
        const command = `node "${path.dirname(wasmPath)}/generate_witness.js" "${wasmPath}" "${inputPath}" "${witnessPath}"`;
        
        execSync(command, { stdio: 'inherit' });
        
        console.log("✅ Witness calculado e salvo em:", witnessPath);
        
    } catch (error) {
        console.error("❌ Erro ao calcular witness:", error.message);
        process.exit(1);
    }
}

// Função para gerar prova completa
async function generateCompleteProof() {
    try {
        console.log("🔐 Gerando prova completa...");
        
        const { execSync } = require("child_process");
        
        // Calcular witness
        await calculateWitness();
        
        // Gerar prova usando prove (mais estável)
        const zkeyPath = path.join(__dirname, "../SuitabilityAssessment_final_new.zkey");
        const witnessPath = path.join(__dirname, "witness.wtns");
        const proofPath = path.join(__dirname, "proof.json");
        const publicPath = path.join(__dirname, "public.json");
        
        const command = `npx snarkjs@0.6.11 groth16 prove "${zkeyPath}" "${witnessPath}" "${proofPath}" "${publicPath}"`;
        
        execSync(command, { stdio: 'inherit' });
        
        console.log("✅ Prova gerada com sucesso!");
        console.log("📄 Prova salva em:", proofPath);
        console.log("📄 Dados públicos salvos em:", publicPath);
        
        // Verificar prova
        await verifyProof();
        
    } catch (error) {
        console.error("❌ Erro ao gerar prova completa:", error.message);
        process.exit(1);
    }
}

// Função para verificar prova
async function verifyProof() {
    try {
        console.log("🔍 Verificando prova...");
        
        const { execSync } = require("child_process");
        const verificationKeyPath = path.join(__dirname, "../verification_key.json");
        const publicPath = path.join(__dirname, "public.json");
        const proofPath = path.join(__dirname, "proof.json");
        
        const command = `npx snarkjs@0.6.11 groth16 verify "${verificationKeyPath}" "${publicPath}" "${proofPath}"`;
        
        execSync(command, { stdio: 'inherit' });
        
        console.log("✅ Prova verificada com sucesso!");
        
    } catch (error) {
        console.error("❌ Erro ao verificar prova:", error.message);
        process.exit(1);
    }
}

// Executar função baseada no argumento da linha de comando
const command = process.argv[2];

switch (command) {
    case "generate":
        generateProof();
        break;
    case "witness":
        calculateWitness();
        break;
    case "prove":
        generateCompleteProof();
        break;
    case "verify":
        verifyProof();
        break;
    default:
        console.log("📖 Uso:");
        console.log("  node generateProof.js generate  - Gerar dados de entrada");
        console.log("  node generateProof.js witness  - Calcular witness");
        console.log("  node generateProof.js prove    - Gerar prova completa");
        console.log("  node generateProof.js verify   - Verificar prova");
        break;
}
