// Tipos para o questionário de suitability
export interface Question {
  id: number;
  text: string;
  options: string[];
  weight: number;
}

export interface SuitabilityResult {
  riskProfile: number; // 0-15 (soma de todas as respostas ponderadas)
  riskLevel: "conservative" | "moderate" | "sophisticated";
  isSuitable: boolean;
  answers: number[];
  totalScore: number;
}

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
