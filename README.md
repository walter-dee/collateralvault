# NFT-Backed Lending Protocol

A decentralized lending protocol built on Stacks blockchain that enables borrowers to collateralize loans with NFT assets and lenders to earn yield by funding loans.

## Overview

This smart contract implements a peer-to-peer lending system where:
- **Borrowers** lock NFTs as collateral to create loans with defined terms
- **Lenders** fund loans and receive repayment with interest
- **Collateral** is automatically claimable if the borrower defaults

## Features

### Core Functionality
- **Create Loan**: Borrowers initiate loans by locking NFT collateral and defining repayment terms
- **Fund Loan**: Lenders provide STX capital in exchange for repayment obligations
- **Repay Loan**: Borrowers repay loans to retrieve their NFT collateral
- **Claim Collateral**: Lenders claim NFT collateral if borrowers default on payments

### SIP009 NFT Integration
- Full SIP009 non-fungible token standard compliance
- Support for up to 1000 tokens per owner
- Token URI metadata resolution
- Ownership tracking per principal

## Contract Functions

### Public Functions

#### `create-loan`
Creates a new loan with NFT collateral.
