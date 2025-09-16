# Zero-Knowledge Proofs

This project implements an investor suitability assessment system and private swaps using Zero-Knowledge Proofs (ZKP) with Circom and SnarkJS. The system allows a user to prove they have an adequate risk profile without revealing their specific questionnaire responses.

## 🏗️ Architecture

The project includes two main circuits:

### 1. Suitability Circuit (`circuits/Suitability.circom`)

The suitability assessment circuit implements:

- **Private inputs**: 5 questionnaire responses (0-3 each)
- **Public inputs**: minimum threshold and calculated risk profile
- **Public output**: indicates if the profile meets the threshold (0 or 1)

#### Objective

The goal is to create a system where:

- A user answers 5 suitability questions
- Each answer has a specific weight
- The system calculates a risk profile (0-10)
- The user can prove their profile meets a minimum threshold
- **Without revealing their specific responses**

#### Question Weights

| Question | Weight | Description           |
| -------- | ------ | --------------------- |
| 1        | 2      | Investment experience |
| 2        | 3      | Risk tolerance        |
| 3        | 2      | Time horizon          |
| 4        | 1      | Financial objectives  |
| 5        | 2      | Market knowledge      |

#### Risk Profile Calculation

```
weightedSum = answer1*2 + answer2*3 + answer3*2 + answer4*1 + answer5*2
maxPossibleScore = 4 * (2+3+2+1+2) = 40
riskProfile = (weightedSum * 10) / maxPossibleScore
```

### 2. Private Swap Intent Circuit (`circuits/PrivateSwapIntent.circom`)

The private swap intent circuit implements:

- **Private inputs**: amount, direction, sender, timestamp
- **Public outputs**: poseidon hash and public parameters
- **Purpose**: Prove swap intent without revealing sensitive details

## 🚀 Installation and Setup

### Prerequisites

```bash
# Install global dependencies
npm install -g circom snarkjs

# Install project dependencies
yarn install
```

### Quick Start

The project uses a unified ZK pipeline script that handles all operations:

```bash
# Complete setup for Suitability circuit (default)
yarn setup

# Generate new proof only (reuses existing setup)
yarn prove

# Run tests
yarn test
```

### Working with Different Circuits

```bash
# Setup and prove Suitability circuit
yarn setup-suitability
yarn prove-suitability

# Setup and prove PrivateSwapIntent circuit
yarn setup-private-swap
yarn prove-private-swap
```

### Using Example Inputs

The project includes example input files for testing:

```bash
# Copy example files for testing
cp scripts/Suitability_input.example.json scripts/Suitability_input.json
cp scripts/PrivateSwapIntent_input.example.json scripts/PrivateSwapIntent_input.json

# Modify the copied files with your test values
# Then generate proofs
yarn prove-suitability
yarn prove-private-swap
```

## 📋 Detailed Workflow

### 1. Complete ZK Pipeline

The `zk_pipeline.sh` script handles the entire ZK workflow:

```bash
# Full setup (first time)
./scripts/zk_pipeline.sh --force-setup

# Generate new proof only (reuses existing setup)
./scripts/zk_pipeline.sh --new-proof

# Default behavior (setup if needed, then prove)
./scripts/zk_pipeline.sh
```

### 2. What the Pipeline Does

#### Compilation Phase:

- Compiles the Circom circuit
- Generates R1CS constraints
- Creates WASM and JavaScript files
- Generates circuit symbols

#### Setup Phase (--force-setup):

- Generates Powers of Tau (Phase 1)
- Contributes to Powers of Tau
- Prepares Phase 2
- Sets up Groth16 circuit
- Contributes to ZKey
- Exports verification key
- Generates Solidity verifier contract

#### Proof Generation:

- Calculates circuit witness
- Generates ZK proof
- Verifies proof off-chain
- Exports artifacts for Solidity

### 3. Generated Artifacts

The pipeline creates all necessary files:

```
Example for Suitability:
artifacts/
├── Suitability.r1cs              # Circuit constraints
├── Suitability_js/               # JavaScript witness calculator
├── Suitability_cpp/              # C++ witness calculator
├── Suitability.sym               # Circuit symbols
├── pot/                          # Powers of Tau and ZKeys
│   ├── Suitability_0000.zkey
│   ├── Suitability_0001.zkey
│   └── Suitability_verification_key.json
├── Suitability_proof.json        # ZK proof
├── Suitability_public.json       # Public inputs
└── Suitability_witness.wtns      # Circuit witness

scripts/                          # Input files
├── Suitability_input.json        # Current Suitability input
├── Suitability_input.example.json # Example Suitability input
├── PrivateSwapIntent_input.json  # Current PrivateSwapIntent input
├── PrivateSwapIntent_input.example.json # Example PrivateSwapIntent input
└── zk_pipeline.sh               # Main ZK pipeline script

../foundry/                       # Solidity integration
├── SuitabilityVerifier.sol       # Generated verifier contract
├── solidityInputs.json           # Proof data for contract calls
├── solidityInputs.decimal.json   # Decimal format
├── solidityInputs.ui.json        # UI format
└── solidityCalldata.txt          # Raw calldata
```

## 🔧 Available Scripts

| Script         | Description                                                |
| -------------- | ---------------------------------------------------------- |
| `yarn compile` | Compiles the Circom circuit only                           |
| `yarn setup`   | Complete ZK setup for Suitability (default)                |
| `yarn prove`   | Generate new proof for Suitability (reuses existing setup) |
| `yarn test`    | Runs system tests                                          |

### Circuit-Specific Commands

| Script                    | Description                                      |
| ------------------------- | ------------------------------------------------ |
| `yarn setup-suitability`  | Complete ZK setup for Suitability circuit        |
| `yarn prove-suitability`  | Generate new proof for Suitability circuit       |
| `yarn setup-private-swap` | Complete ZK setup for PrivateSwapIntent circuit  |
| `yarn prove-private-swap` | Generate new proof for PrivateSwapIntent circuit |

## 🧪 Tests

The system includes comprehensive tests:

```bash
yarn test
```

Tests scenarios such as:

- Low risk profile
- Medium risk profile
- High risk profile
- Different thresholds
- Constraint validation

## 📝 Input Examples

### Suitability Circuit Input

The Suitability circuit requires specific input format with questionnaire responses and validation parameters:

```json
{
  "answer1": 3, // Investment experience (0-3)
  "answer2": 2, // Risk tolerance (0-3)
  "answer3": 1, // Time horizon (0-3)
  "answer4": 2, // Financial objectives (0-3)
  "answer5": 3, // Market knowledge (0-3)
  "wallet": "0x1234567890AbcdEF1234567890aBcdef12345678", // User wallet address
  "thresholdScaled": 20, // Minimum threshold (0-100, where 100 = 10.0)
  "isSuitablePub": 1 // Expected result (0=Unsuitable, 1=Suitable)
}
```

#### Field Descriptions:

- **answer1-5**: Questionnaire responses (0-3 scale)
  - `0`: Lowest risk/conservative option
  - `3`: Highest risk/aggressive option
- **wallet**: User's wallet address for identification
- **thresholdScaled**: Minimum risk threshold (scaled by 10, so 20 = 2.0)
- **isSuitablePub**: Expected suitability result for validation

### PrivateSwapIntent Circuit Input

The PrivateSwapIntent circuit requires swap parameters and commitment data:

```json
{
  "amountIn": "100", // Amount to swap (string for large numbers)
  "zeroForOne": "1", // Swap direction (0=Token1→Token0, 1=Token0→Token1)
  "sender": "0x1234567890AbcdEF1234567890aBcdef12345678", // Sender address
  "timestamp": "1697052800" // Unix timestamp of swap intent
}
```

#### Field Descriptions:

- **amountIn**: Swap amount (use string format for large numbers)
- **zeroForOne**: Direction flag (0 or 1)
- **sender**: Address of the swap initiator
- **timestamp**: When the swap intent was created

### Testing with Examples

To test different scenarios, use the provided example files:

```bash
# Copy example files for testing
cp scripts/Suitability_input.example.json scripts/Suitability_input.json
cp scripts/PrivateSwapIntent_input.example.json scripts/PrivateSwapIntent_input.json

# Modify values in the copied files as needed
# Then run the proof generation
yarn prove-suitability
yarn prove-private-swap
```

#### Example Scenarios:

**Suitable Profile (High Risk Tolerance):**

```json
{
  "answer1": 3,
  "answer2": 3,
  "answer3": 2,
  "answer4": 3,
  "answer5": 3,
  "thresholdScaled": 15,
  "isSuitablePub": 1
}
```

**Unsuitable Profile (Low Risk Tolerance):**

```json
{
  "answer1": 0,
  "answer2": 0,
  "answer3": 0,
  "answer4": 0,
  "answer5": 0,
  "thresholdScaled": 25,
  "isSuitablePub": 0
}
```

**Large Swap Intent:**

```json
{
  "amountIn": "1000000000000000000", // 1 ETH in wei
  "zeroForOne": "0", // Token1 → Token0
  "sender": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6",
  "timestamp": "1700000000"
}
```

## 🔐 Solidity Integration

The pipeline automatically generates a Solidity verifier contract that allows:

- Verify ZK proofs on-chain
- Store suitability status by address
- Revoke suitability (owner only)
- Track verifications

### Generated Contract

The `SuitabilityVerifier.sol` contract is automatically generated and includes:

```solidity
function verifyProof(
    uint256[2] memory a,
    uint256[2][2] memory b,
    uint256[2] memory c,
    uint256[] memory input
) public view returns (bool)
```

### Using Generated Artifacts

The pipeline creates ready-to-use files for contract integration:

```bash
# Test the generated contract
ADDR=<contract_address> ./cast_call.sh

# Use solidityInputs.json in your frontend
const proofData = require('../foundry/solidityInputs.json');
```

## 🛡️ Security

### Privacy

- **Private responses**: Never revealed
- **Calculated profile**: Can be public
- **Threshold**: Can be public
- **Result**: Can be public

### Validation

- Constraints ensure valid responses (0-3)
- Consistency verification between profile and threshold
- Boundary validation (0-10)

## 🔄 Scaffold-ETH 2 Integration

To integrate with the frontend:

1. **Run the ZK pipeline**:

```bash
yarn setup
```

2. **Deploy the contract**:

```bash
cd ../foundry
forge build
forge script script/DeploySuitabilityVerifier.s.sol --rpc-url http://localhost:8545 --broadcast
```

3. **Use Scaffold-ETH hooks**:

```typescript
const { writeContractAsync: verifySuitabilityAsync } = useScaffoldWriteContract(
  {
    contractName: "SuitabilityVerifier",
  }
);

// Verify suitability using generated proof data
const proofData = require("../foundry/solidityInputs.json");
await verifySuitabilityAsync({
  functionName: "verifyProof",
  args: [proofData[0], proofData[1], proofData[2], proofData[3]],
});
```

## 📈 Next Steps

1. **Complete on-chain verification implementation**
2. **User interface for questionnaire**
3. **Verifiable credentials system**
4. **Integration with KYC providers**
5. **Security audit**

## 🤝 Contributing

1. Fork the project
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📄 License

MIT License - see the [LICENSE](../LICENSE) file for details.

## 🆘 Support

For questions or issues:

1. Check the documentation
2. Run the tests
3. Open a GitHub issue

---

**Note**: This is an educational project. For production use, consider security audits and more robust implementations.
