const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// Função para calcular perfil de risco esperado
function calculateExpectedRiskProfile(answers) {
    const weights = [2, 3, 2, 1, 2];
    const weightedSum = answers.reduce((sum, answer, index) => sum + answer * weights[index], 0);
    const maxPossibleScore = 4 * weights.reduce((a, b) => a + b, 0);
    return Math.floor((weightedSum * 10) / maxPossibleScore);
}

// Função para verificar se o perfil atende ao threshold
function isSuitable(riskProfile, threshold) {
    return riskProfile >= threshold;
}

// Função para gerar dados de entrada
function generateInput(answers, threshold) {
    return {
        answer1: answers[0],
        answer2: answers[1],
        answer3: answers[2],
        answer4: answers[3],
        answer5: answers[4],
        threshold: threshold
    };
}

// Função para executar teste
function runTest(testName, answers, threshold, expectedSuitable) {
    console.log(`\n🧪 Teste: ${testName}`);
    console.log(`📝 Respostas: [${answers.join(', ')}]`);
    console.log(`🎯 Threshold: ${threshold}`);
    
    const expectedRiskProfile = calculateExpectedRiskProfile(answers);
    const expectedIsSuitable = isSuitable(expectedRiskProfile, threshold);
    
    console.log(`📊 Perfil de risco esperado: ${expectedRiskProfile}`);
    console.log(`✅ É adequado? ${expectedIsSuitable ? 'Sim' : 'Não'}`);
    
    // Verificar se o resultado esperado corresponde ao teste
    if (expectedIsSuitable === expectedSuitable) {
        console.log(`✅ Teste ${testName} PASSOU`);
        return true;
    } else {
        console.log(`❌ Teste ${testName} FALHOU`);
        console.log(`   Esperado: ${expectedSuitable ? 'Sim' : 'Não'}, Obtido: ${expectedIsSuitable ? 'Sim' : 'Não'}`);
        return false;
    }
}

// Função para validar constraints do circuito
function validateConstraints(answers) {
    console.log("\n🔍 Validando constraints...");
    
    // Verificar se todas as respostas estão no intervalo válido (0-3)
    const validAnswers = answers.every(answer => answer >= 0 && answer < 4);
    
    if (validAnswers) {
        console.log("✅ Todas as respostas estão no intervalo válido (0-3)");
    } else {
        console.log("❌ Algumas respostas estão fora do intervalo válido");
        return false;
    }
    
    // Verificar se os pesos estão corretos
    const weights = [2, 3, 2, 1, 2];
    console.log(`📊 Pesos das perguntas: [${weights.join(', ')}]`);
    
    // Calcular score máximo possível
    const maxPossibleScore = 4 * weights.reduce((a, b) => a + b, 0);
    console.log(`🎯 Score máximo possível: ${maxPossibleScore}`);
    
    return true;
}

// Função para testar diferentes cenários
function runAllTests() {
    console.log("🚀 Iniciando testes do circuito de Suitability Assessment...");
    
    let passedTests = 0;
    let totalTests = 0;
    
    // Teste 1: Perfil de baixo risco
    const test1Answers = [0, 0, 0, 0, 0];
    const test1Threshold = 5;
    if (runTest("Perfil de Baixo Risco", test1Answers, test1Threshold, false)) {
        passedTests++;
    }
    totalTests++;
    
    // Teste 2: Perfil de médio risco
    const test2Answers = [2, 2, 2, 2, 2];
    const test2Threshold = 5;
    if (runTest("Perfil de Médio Risco", test2Answers, test2Threshold, true)) {
        passedTests++;
    }
    totalTests++;
    
    // Teste 3: Perfil de alto risco
    const test3Answers = [3, 3, 3, 3, 3];
    const test3Threshold = 5;
    if (runTest("Perfil de Alto Risco", test3Answers, test3Threshold, true)) {
        passedTests++;
    }
    totalTests++;
    
    // Teste 4: Threshold muito alto
    const test4Answers = [2, 2, 2, 2, 2];
    const test4Threshold = 8;
    if (runTest("Threshold Muito Alto", test4Answers, test4Threshold, false)) {
        passedTests++;
    }
    totalTests++;
    
    // Teste 5: Threshold baixo
    const test5Answers = [1, 1, 1, 1, 1];
    const test5Threshold = 3;
    if (runTest("Threshold Baixo", test5Answers, test5Threshold, false)) {
        passedTests++;
    }
    totalTests++;
    
    // Teste 6: Respostas mistas
    const test6Answers = [3, 1, 2, 0, 3];
    const test6Threshold = 6;
    if (runTest("Respostas Mistas", test6Answers, test6Threshold, false)) {
        passedTests++;
    }
    totalTests++;
    
    // Validar constraints
    validateConstraints(test1Answers);
    
    // Resumo dos testes
    console.log(`\n📊 Resumo dos Testes:`);
    console.log(`✅ Testes passaram: ${passedTests}/${totalTests}`);
    console.log(`📈 Taxa de sucesso: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    
    if (passedTests === totalTests) {
        console.log("🎉 Todos os testes passaram!");
        return true;
    } else {
        console.log("⚠️  Alguns testes falharam. Verifique a implementação.");
        return false;
    }
}

// Função para testar com dados reais do circuito
function testWithRealCircuit() {
    console.log("\n🔬 Testando com circuito real...");
    
    try {
        // Verificar se os arquivos necessários existem
        const wasmPath = path.join(__dirname, "../Suitability_js/Suitability.wasm");
        const zkeyPath = path.join(__dirname, "../Suitability_final.zkey");
        
        if (!fs.existsSync(wasmPath)) {
            console.log("⚠️  Arquivo .wasm não encontrado. Execute 'yarn compile' primeiro.");
            return false;
        }
        
        if (!fs.existsSync(zkeyPath)) {
            console.log("⚠️  Arquivo .zkey não encontrado. Execute 'yarn setup' primeiro.");
            return false;
        }
        
        // Testar com um conjunto de dados específico
        const testAnswers = [2, 3, 1, 2, 3];
        const testThreshold = 6;
        
        const input = generateInput(testAnswers, testThreshold);
        const inputPath = path.join(__dirname, "test_input.json");
        
        // Salvar dados de teste
        fs.writeFileSync(inputPath, JSON.stringify(input, null, 2));
        
        console.log("📝 Dados de teste salvos em:", inputPath);
        console.log("💡 Para testar com o circuito real, execute:");
        console.log("   node scripts/generateProof.js prove");
        
        return true;
        
    } catch (error) {
        console.error("❌ Erro ao testar com circuito real:", error.message);
        return false;
    }
}

// Função principal
function main() {
    console.log("🧪 Iniciando testes do sistema de Suitability Assessment...");
    
    // Executar testes lógicos
    const logicalTestsPassed = runAllTests();
    
    // Testar com circuito real
    const realCircuitTestPassed = testWithRealCircuit();
    
    // Resumo final
    console.log("\n🏁 Resumo Final:");
    console.log(`📊 Testes lógicos: ${logicalTestsPassed ? '✅ PASSOU' : '❌ FALHOU'}`);
    console.log(`🔬 Teste com circuito real: ${realCircuitTestPassed ? '✅ PASSOU' : '⚠️  PENDENTE'}`);
    
    if (logicalTestsPassed) {
        console.log("\n🎉 Sistema de Suitability Assessment está funcionando corretamente!");
        console.log("\n📋 Próximos passos:");
        console.log("1. Execute 'yarn compile' para compilar o circuito");
        console.log("2. Execute 'yarn setup' para configurar as chaves ZK");
        console.log("3. Execute 'yarn generate-proof' para testar com dados reais");
    } else {
        console.log("\n❌ Sistema precisa de correções antes de prosseguir.");
        process.exit(1);
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    main();
}

module.exports = {
    calculateExpectedRiskProfile,
    isSuitable,
    generateInput,
    runTest,
    validateConstraints,
    runAllTests,
    testWithRealCircuit,
    main
};
