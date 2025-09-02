const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// Função para criar diretório pot se não existir
function createPotDirectory() {
    const potDir = path.join(__dirname, "../pot");
    if (!fs.existsSync(potDir)) {
        fs.mkdirSync(potDir, { recursive: true });
        console.log("📁 Diretório pot criado");
    }
}

// Função para verificar se o SnarkJS está instalado
function checkSnarkJS() {
    try {
        execSync("/opt/homebrew/bin/snarkjs --version", { stdio: 'pipe' });
        console.log("✅ SnarkJS encontrado");
        return true;
    } catch (error) {
        console.error("❌ SnarkJS não encontrado. Instale com: npm install -g snarkjs");
        return false;
    }
}

// Função para gerar Powers of Tau
async function generatePowersOfTau() {
    try {
        console.log("🔧 Gerando Powers of Tau...");
        
        const potDir = path.join(__dirname, "../pot");
        const potFile = path.join(potDir, "pot12_0000.ptau");
        
        // Verificar se já existe
        if (fs.existsSync(potFile)) {
            console.log("ℹ️  Powers of Tau já existe, pulando geração...");
            return potFile;
        }
        
        // Gerar novo Powers of Tau
        const command = `/opt/homebrew/bin/snarkjs powersoftau new bn128 12 ${potFile} -v`;
        execSync(command, { stdio: 'inherit', cwd: potDir });
        
        console.log("✅ Powers of Tau gerado com sucesso");
        return potFile;
        
    } catch (error) {
        console.error("❌ Erro ao gerar Powers of Tau:", error.message);
        throw error;
    }
}

// Função para contribuir para Powers of Tau
async function contributeToPowersOfTau(potFile) {
    try {
        console.log("🎲 Contribuindo para Powers of Tau...");
        
        const potDir = path.dirname(potFile);
        const contributionFile = path.join(potDir, "pot12_0001.ptau");
        
        // Verificar se já existe contribuição
        if (fs.existsSync(contributionFile)) {
            console.log("ℹ️  Contribuição já existe, pulando...");
            return contributionFile;
        }
        
        // Fazer contribuição
        const command = `/opt/homebrew/bin/snarkjs powersoftau contribute ${potFile} ${contributionFile} --name="First contribution" -v`;
        execSync(command, { stdio: 'inherit', cwd: potDir });
        
        console.log("✅ Contribuição realizada com sucesso");
        return contributionFile;
        
    } catch (error) {
        console.error("❌ Erro ao contribuir para Powers of Tau:", error.message);
        throw error;
    }
}

// Função para finalizar Powers of Tau
async function finalizePowersOfTau(contributionFile) {
    try {
        console.log("🏁 Finalizando Powers of Tau...");
        
        const potDir = path.dirname(contributionFile);
        const finalFile = path.join(potDir, "pot12_final.ptau");
        
        // Verificar se já existe arquivo final
        if (fs.existsSync(finalFile)) {
            console.log("ℹ️  Powers of Tau final já existe, pulando...");
            return finalFile;
        }
        
        // Finalizar
        const command = `/opt/homebrew/bin/snarkjs powersoftau beacon ${contributionFile} ${finalFile} 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon"`;
        execSync(command, { stdio: 'inherit', cwd: potDir });
        
        console.log("✅ Powers of Tau finalizado com sucesso");
        return finalFile;
        
    } catch (error) {
        console.error("❌ Erro ao finalizar Powers of Tau:", error.message);
        throw error;
    }
}

// Função para preparar fase 2
async function preparePhase2(potFile) {
    try {
        console.log("🔄 Preparando Fase 2...");
        
        const potDir = path.dirname(potFile);
        const phase2File = path.join(potDir, "pot12_final_phase2.ptau");
        
        // Verificar se já existe
        if (fs.existsSync(phase2File)) {
            console.log("ℹ️  Fase 2 já existe, pulando...");
            return phase2File;
        }
        
        // Preparar fase 2
        const command = `/opt/homebrew/bin/snarkjs powersoftau prepare phase2 ${potFile} ${phase2File} -v`;
        execSync(command, { stdio: 'inherit', cwd: potDir });
        
        console.log("✅ Fase 2 preparada com sucesso");
        return phase2File;
        
    } catch (error) {
        console.error("❌ Erro ao preparar Fase 2:", error.message);
        throw error;
    }
}

// Função para setup do circuito
async function setupCircuit(phase2File) {
    try {
        console.log("⚙️  Configurando circuito...");
        
        const circuitsDir = path.join(__dirname, "../circuits");
        const r1csFile = path.join(circuitsDir, "SuitabilityAssessment.r1cs");
        const zkeyFile = path.join(circuitsDir, "SuitabilityAssessment_0000.zkey");
        
        // Verificar se o circuito foi compilado
        if (!fs.existsSync(r1csFile)) {
            throw new Error("Circuito não compilado. Execute 'yarn compile' primeiro.");
        }
        
        // Verificar se já existe zkey
        if (fs.existsSync(zkeyFile)) {
            console.log("ℹ️  ZKey já existe, pulando setup...");
            return zkeyFile;
        }
        
        // Setup do circuito
        const command = `/opt/homebrew/bin/snarkjs groth16 setup ${r1csFile} ${phase2File} ${zkeyFile}`;
        execSync(command, { stdio: 'inherit', cwd: circuitsDir });
        
        console.log("✅ Circuito configurado com sucesso");
        return zkeyFile;
        
    } catch (error) {
        console.error("❌ Erro ao configurar circuito:", error.message);
        throw error;
    }
}

// Função para contribuir para zkey
async function contributeToZKey(zkeyFile) {
    try {
        console.log("🎲 Contribuindo para ZKey...");
        
        const circuitsDir = path.dirname(zkeyFile);
        const finalZkeyFile = path.join(circuitsDir, "SuitabilityAssessment_final.zkey");
        
        // Verificar se já existe zkey final
        if (fs.existsSync(finalZkeyFile)) {
            console.log("ℹ️  ZKey final já existe, pulando contribuição...");
            return finalZkeyFile;
        }
        
        // Contribuir para zkey
        const command = `/opt/homebrew/bin/snarkjs zkey contribute ${zkeyFile} ${finalZkeyFile} --name="First contribution" -v`;
        execSync(command, { stdio: 'inherit', cwd: circuitsDir });
        
        console.log("✅ Contribuição para ZKey realizada com sucesso");
        return finalZkeyFile;
        
    } catch (error) {
        console.error("❌ Erro ao contribuir para ZKey:", error.message);
        throw error;
    }
}

// Função para exportar chave de verificação
async function exportVerificationKey(zkeyFile) {
    try {
        console.log("🔑 Exportando chave de verificação...");
        
        const circuitsDir = path.dirname(zkeyFile);
        const verificationKeyFile = path.join(circuitsDir, "verification_key.json");
        
        // Verificar se já existe
        if (fs.existsSync(verificationKeyFile)) {
            console.log("ℹ️  Chave de verificação já existe, pulando...");
            return verificationKeyFile;
        }
        
        // Exportar chave de verificação
        const command = `/opt/homebrew/bin/snarkjs zkey export verificationkey ${zkeyFile} ${verificationKeyFile}`;
        execSync(command, { stdio: 'inherit', cwd: circuitsDir });
        
        console.log("✅ Chave de verificação exportada com sucesso");
        return verificationKeyFile;
        
    } catch (error) {
        console.error("❌ Erro ao exportar chave de verificação:", error.message);
        throw error;
    }
}

// Função principal
async function main() {
    try {
        console.log("🚀 Iniciando setup completo do sistema ZK...");
        
        // Verificar SnarkJS
        if (!checkSnarkJS()) {
            process.exit(1);
        }
        
        // Criar diretório pot
        createPotDirectory();
        
        // Gerar Powers of Tau
        const potFile = await generatePowersOfTau();
        
        // Contribuir para Powers of Tau
        const contributionFile = await contributeToPowersOfTau(potFile);
        
        // Finalizar Powers of Tau
        const finalPotFile = await finalizePowersOfTau(contributionFile);
        
        // Preparar Fase 2
        const phase2File = await preparePhase2(finalPotFile);
        
        // Setup do circuito
        const zkeyFile = await setupCircuit(phase2File);
        
        // Contribuir para ZKey
        const finalZkeyFile = await contributeToZKey(zkeyFile);
        
        // Exportar chave de verificação
        await exportVerificationKey(finalZkeyFile);
        
        console.log("\n🎉 Setup completo realizado com sucesso!");
        console.log("\n📋 Próximos passos:");
        console.log("1. Execute: yarn generate-proof");
        console.log("2. Teste o sistema com diferentes inputs");
        console.log("3. Integre com o contrato Solidity");
        
    } catch (error) {
        console.error("❌ Erro durante setup:", error.message);
        process.exit(1);
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    main();
}

module.exports = {
    main,
    generatePowersOfTau,
    contributeToPowersOfTau,
    finalizePowersOfTau,
    preparePhase2,
    setupCircuit,
    contributeToZKey,
    exportVerificationKey
};
