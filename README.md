# Preservia: Heritage Preservation DAO

Preservia is a decentralized autonomous organization (DAO) built on Stacks blockchain for preserving cultural heritage sites and artifacts through tokenization and community governance.

## Overview

Cultural heritage preservation faces significant funding challenges globally. Preservia solves this by creating a decentralized platform where:

1. Cultural artifacts and heritage sites can be registered
2. Community members can propose preservation initiatives
3. Token holders vote on and fund proposals
4. Contributors receive ownership shares in preserved assets

## Technical Architecture

Preservia is built using Clarity smart contracts on the Stacks blockchain, featuring:

- **Fungible Token (FT)**: PRSV tokens for governance and ownership
- **Asset Registry**: On-chain registry of heritage assets with metadata
- **DAO Governance**: Proposal and voting system for community decisions
- **Ownership Tracking**: Fractional ownership through asset shares

## Key Features

### Heritage Asset Registration

Cultural heritage sites and artifacts can be registered with detailed information including:
- Name and description
- Location
- Creation date
- Cultural significance
- Preservation status
- Funding goals

### Proposal System

Community members can create proposals for preservation initiatives, specifying:
- Target heritage asset
- Funding amount
- Detailed preservation plan
- Voting deadline

### Governance

Token-weighted voting allows community members to:
- Vote on active proposals
- Finalize proposals after deadline
- Execute approved proposals

### Direct Contributions

Members can donate directly to specific heritage assets, receiving ownership shares proportional to their contributions.

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity smart contract development environment
- [Stacks Wallet](https://www.hiro.so/wallet) - For interacting with the deployed contract

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yinye2/preservia.git
cd preservia
```

2. Install dependencies:
```bash
npm install
```

3. Test the contract:
```bash
clarinet test
```

### Deployment

The contract can be deployed to the Stacks testnet or mainnet using Clarinet:

```bash
clarinet deploy --testnet
```

## Contract Interaction

### Register a Heritage Asset

```clarity
(contract-call? .preservia register-heritage-asset "Parthenon" "Ancient Greek temple" "Athens, Greece" u432 "Symbolizes the power of Athens and democracy" u1000000 "needs-restoration" none)
```

### Create a Preservation Proposal

```clarity
(contract-call? .preservia create-proposal u1 "Restore Parthenon West Pediment" "Detailed restoration of the west pediment sculptures" u200000 "Restoration plan includes..." u300)
```

### Vote on a Proposal

```clarity
(contract-call? .preservia vote-on-proposal u1 true u500)
```

## Contributing

We welcome contributions to Preservia! 

## Acknowledgments

- UNESCO for inspiration and heritage preservation standards
- Stacks Foundation for blockchain infrastructure
- Open source community for tools and resources

