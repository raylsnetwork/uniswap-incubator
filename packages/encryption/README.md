# Encryption Package

This package provides encryption utilities for the UHI6 project, including AES encryption/decryption functionality for secure data handling.

## Features

- AES encryption and decryption
- Secure key management
- JSON data encryption/decryption
- Integration with the main project

## Usage

```javascript
// Encrypt data
const encrypted = await encrypt(data, key);

// Decrypt data
const decrypted = await decrypt(encrypted, key);
```

## Installation

```bash
yarn install
```

## Scripts

- `encrypt.js` - Encryption utility
- `decrypt.cjs` - Decryption utility

## Security

This package uses industry-standard AES encryption for secure data handling. Always ensure proper key management in production environments.