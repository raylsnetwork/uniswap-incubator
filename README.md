# 🪝 Rayls Hook - Uniswap Hook Incubator 6

<h4 align="center">
  <a href="#-architecture">Architecture</a> |
  <a href="#-quick-start">Quick Start</a> |
  <a href="#-roadmap">Roadmap</a> |
  <a href="#-contributing">Contributing</a>
</h4>

<p align="center">
  <img src="https://img.shields.io/badge/Scaffold--ETH%202-Base-blue" alt="Scaffold-ETH 2 Base">
  <img src="https://img.shields.io/badge/Zero--Knowledge-Proofs-green" alt="Zero-Knowledge Proofs">
  <img src="https://img.shields.io/badge/Uniswap%20v4-Hooks-orange" alt="Uniswap v4 Hooks">
  <img src="https://img.shields.io/badge/TypeScript-Ready-blue" alt="TypeScript">
</p>

**Rayls Hook** introduces two complementary ZK-SNARK enabled features built on Uniswap v4 hooks:

1. 🛡️ Suitability Verifier Logic – A privacy-preserving investor suitability assessment system. It allows users to prove their investment suitability without revealing their specific questionnaire responses using Zero-Knowledge Proofs.

2. [🔐 Private Swap Logic](./docs/privateSwaps.md) (click for more info) – Private swaps with an execution timestamp. Swap values remain hidden and are committed on-chain through a commitment ID, then later executed and validated and revealed with zkSNARK proofs. The values are also encrypted with an Auditor’s wallet public key (optional), and the ciphertext is stored on-chain, enabling the Auditor to independently verify commitments at any time.

There's no integration with Hackaton partners but for private swaps, while commitments and encrypted payloads are currently stored fully on-chain, they could instead be stored in EigenDA with only lightweight references on-chain, reducing gas costs and improving scalability without compromising verifiability.

⚙️ Built using **Scaffold-ETH 2** as the foundation, with **NextJS**, **RainbowKit**, **Foundry**, **Wagmi**, **Circom**, **SnarkJS**, and **TypeScript**.

## 🎯 Project Overview

🛡️ Suitability Verifier Logic

- ✅ **Private Questionnaire**: Users answer 5 suitability questions without revealing their responses
- 🔐 **Zero-Knowledge Proofs**: Prove investment suitability using Circom circuits
- 🪝 **Uniswap v4 Integration**: Seamless integration with Uniswap v4 hooks
- 📊 **Risk Profiling**: Calculate and verify risk profiles (0-10 scale)
- 🛡️ **Privacy-First**: Never reveal private questionnaire data
- ⚡ **On-Chain Verification**: Smart contract verification of ZK proofs

🔐 Private Swap Logic

- ✅ Encrypted Commitments: Users (or backend services) create encrypted swap commitments
- ⏳ Deferred Execution: Commitments become executable only after a timestamp
- 🔏 ZK Proof of Intent: Execution requires a zkSNARK proof proving knowledge of commitment id
- 📡 Auditor Access: Commitments include encrypted values for auditors to decrypt
- 🪝 Uniswap v4 Integration: Hook contract executes swaps using permit + safe transfer logic

## 🏗️ Architecture

### System Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │    │   ZK Circuits    │    │ Smart Contracts │
│   (NextJS)      │◄──►│   (Circom)       │◄──►│   (Solidity)    │
│                 │    │                  │    │                 │
│ • Questionnaire │    │ • Suitability    │    │ • Verifiers     │
│ • Proof Gen     │    │ • PrivateSwap    │    │ • Uniswap Hooks │
│ • UI Components │    │ • Poseidon Hash  │    │ • Integration   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

- Suitability Verifier Logic lives in circuits + verifier contracts

- Private Swap Logic lives in the hook contracts + zk circuits + auditor encrypt/decrypt scripts.

### Technology Stack

| Layer               | Technology              | Purpose                         |
| ------------------- | ----------------------- | ------------------------------- |
| **ZK Layer**        | Circom + SnarkJS        | Zero-knowledge proof generation |
| **Smart Contracts** | Solidity + Foundry      | On-chain verification           |
| **Frontend**        | NextJS + Scaffold-ETH 2 | User interface                  |
| **Integration**     | Uniswap v4 Hooks        | DEX integration                 |
| **Development**     | TypeScript + Wagmi      | Type-safe development           |

### Circuit Architecture

#### Suitability Assessment Circuit

- **Private Inputs**: 5 questionnaire responses (0-3 scale)
- **Public Inputs**: Risk threshold and calculated profile
- **Output**: Suitability verification (0 or 1)

#### Private Swap Intent Circuit

- **Private Inputs**: amountIn, zeroForOne, sender, timestamp
- **Public Outputs**: Commitment hash and verification data
- **Purpose**: Prove swap intent without revealing sensitive details

## ⚙️ Requirements

Before you begin, you need to install the following tools:

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- [Yarn](https://yarnpkg.com/getting-started/install) (v1 or v2+)
- [Git](https://git-scm.com/downloads)
- [Circom](https://docs.circom.io/getting-started/installation/) (for ZK circuits)
- [SnarkJS](https://github.com/iden3/snarkjs) (for ZK proofs)

## 🚀 Quick Start

To get started with Rayls Hook, follow these steps:

### 1. Install Dependencies

```bash
# Clone the repository
git clone https://github.com/raylsnetwork/uniswap-incubator.git
cd rayls-hook

# Install all dependencies
yarn install
```

### 2. Start Local Blockchain

```bash
# Start local Ethereum network (Scaffold-ETH 2)
yarn workspace foundry chain
```

This command starts a local Ethereum network using Foundry. The network runs on your local machine and can be used for testing and development.

### 3. Setup Zero-Knowledge Circuits

```bash
# Or setup specific circuits
yarn workspace circom setup-suitability      # Suitability assessment circuit
yarn workspace circom setup-private-swap     # Private swap intent circuit
```

### 4. Deploy Smart Contracts

```bash
# Deploy contracts to local network
yarn workspace @se-2/foundry deploy
```

This command deploys the Rayls Hook smart contracts to the local network, including the ZK verifiers and Uniswap v4 hooks.

### 5. Start Frontend

```bash
# Start the NextJS frontend
yarn workspace @se-2/nextjs start
```

Visit your app on: `http://localhost:3000`. You can interact with the suitability assessment and test the ZK proof verification.

### 6. Running tests

```bash
yarn workspace @se-2/foundry test
```

### 7. Check coverage

(We focused on RaylsHook contract for full coverage)

```bash
yarn workspace @se-2/foundry coverage
```

## 🛠️ Development

### Available Commands

| Command                   | Description                              |
| ------------------------- | ---------------------------------------- |
| `yarn chain`              | Start local blockchain                   |
| `yarn deploy`             | Deploy smart contracts                   |
| `yarn start`              | Start frontend                           |
| `yarn setup`              | Setup ZK circuits (default: Suitability) |
| `yarn prove`              | Generate new ZK proof                    |
| `yarn setup-suitability`  | Setup Suitability circuit                |
| `yarn prove-suitability`  | Generate Suitability proof               |
| `yarn setup-private-swap` | Setup PrivateSwapIntent circuit          |
| `yarn prove-private-swap` | Generate PrivateSwapIntent proof         |
| `yarn test`               | Run tests                                |

### Project Structure

```
packages/
├── circom/                    # Zero-Knowledge circuits
│   ├── circuits/              # Circom circuit files
│   ├── scripts/               # ZK pipeline and utilities
│   ├── test/                  # Circuit tests
│   └── artifacts/             # Generated ZK artifacts
├── foundry/                   # Smart contracts
│   ├── contracts/             # Solidity contracts
│   ├── script/                # Deployment scripts
│   └── test/                  # Contract tests
├── nextjs/                    # Frontend application
│   ├── app/                   # NextJS app directory
│   ├── components/            # React components
│   └── hooks/                 # Custom hooks
└── encryption/                # Encryption utilities
```

### Testing ZK Circuits

```bash
# Test with example inputs
cp packages/circom/scripts/Suitability_input.example.json packages/circom/scripts/Suitability_input.json
cp packages/circom/scripts/PrivateSwapIntent_input.example.json packages/circom/scripts/PrivateSwapIntent_input.json

# Modify the input files as needed, then generate proofs
yarn prove-suitability
yarn prove-private-swap
```

## 📋 Roadmap

### Phase 1: Core Infrastructure ✅

- [x] ZK circuits implementation (Suitability + PrivateSwapIntent)
- [x] Smart contract verifiers
- [x] Basic Uniswap v4 hook integration
- [x] ZK proof generation and verification pipeline
- [x] Auditor encryption feature
- [x] Multiple tests

### Phase 2: Frontend Development 🚧

- [ ] Complete UI + BE implementation
- [ ] ZK proof generation interface
- [ ] Real-time proof verification
- [ ] User dashboard and profile management
- [ ] Integration with wallet providers

### Phase 3: Advanced Features 📋

- [ ] Multi-circuit support and management
- [ ] Private Swap multi-auditors support and management
- [ ] Private Swap multi-executors support and management
- [ ] Advanced risk assessment algorithms
- [ ] Compliance and regulatory features
- [ ] Integration with external KYC providers
- [ ] Mobile-responsive design

### Phase 4: Production Ready 🎯

- [ ] Security audits and testing
- [ ] Performance optimization
- [ ] Documentation and tutorials
- [ ] Community features and governance
- [ ] Mainnet deployment

## 🤝 Contributing to Rayls Hook

We welcome contributions to Rayls Hook! This project is part of the Uniswap Hook Incubator 6 program.

### Development Guidelines

1. **Fork the repository** and create a feature branch
2. **Follow the coding standards** established in the project
3. **Test your changes** thoroughly, especially ZK circuits
4. **Update documentation** for any new features
5. **Submit a pull request** with a clear description

### Areas for Contribution

- **Frontend Development**: UI/UX improvements, new components
- **ZK Circuit Optimization**: Performance and security improvements
- **Smart Contract Features**: New functionality and integrations
- **Documentation**: Tutorials, guides, and examples
- **Testing**: Comprehensive test coverage and edge cases

### Getting Help

- Check the [documentation](packages/circom/README.md) for ZK circuits
- Review [Scaffold-ETH 2 docs](https://docs.scaffoldeth.io) for frontend development
- Open an issue for bugs or feature requests
- Join our community discussions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Scaffold-ETH 2** for the excellent development framework
- **Uniswap** for the Hook Incubator program
- **Circom** and **SnarkJS** for ZK proof technology
- **Open source community** for inspiration and support

---

**Note**: This project is part of the Uniswap Hook Incubator 6 program. For production use, consider security audits and additional compliance requirements.
