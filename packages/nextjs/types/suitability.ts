
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
