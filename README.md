# Tokenization Project

This project implements a Tokenization contracts on StarkNet using Cairo. It includes smart contracts for managing tokens, access control, whitelisting, freezing accounts, and more.

## Project Structure

## Key Components

### 1. **AssetToken**
- Implements token functionalities such as minting, burning, freezing, and whitelisting.
- Provides access control using roles like `DEFAULT_ADMIN_ROLE` and `AGENT_ROLE`.

### 2. **Controller**
- Acts as a central contract to manage token-related operations.
- Includes functions for minting, freezing, whitelisting, and managing agents.

### 3. **TokenFactory**
- Facilitates the creation of new token contracts.
- Allows updating the owner and class hash of deployed tokens.

### 4. **TempToken**
- A temporary ERC-20 token for testing purposes.

## Features

- **Access Control**: Role-based access control for secure operations.
- **Whitelisting**: Manage user access to token functionalities.
- **Freezing Accounts**: Temporarily disable token transfers for specific accounts.
- **Batch Operations**: Perform batch minting, burning, freezing, and whitelisting.
- **Event Emission**: Emit events for key operations to enable tracking.

## Dependencies

- [OpenZeppelin](https://github.com/OpenZeppelin/cairo-contracts) (v0.20.0): Provides reusable components for access control, pausing, and token standards.
- [StarkNet](https://starknet.io/) (v2.11.4): StarkNet-specific utilities and interfaces.

## Development

### Prerequisites
- [Scarb](https://docs.swmansion.com/scarb/) for managing Cairo projects.
- [StarkNet CLI](https://starknet.io/docs/quickstart.html) for deploying and interacting with contracts.

### Build
Run the following command to compile the contracts:
```sh
scarb build
```