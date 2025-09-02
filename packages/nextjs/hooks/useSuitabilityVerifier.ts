
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
