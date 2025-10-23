# Musemint

## Overview

**Musemint** is a decentralized royalty distribution system for digital art built on the Stacks blockchain. It automates the tracking and distribution of both **primary sales** and **secondary market royalties**, ensuring that creators and contributors are compensated fairly and transparently. Musemint supports **collaborative artworks**, **NFT contract linking**, and **on-chain royalty claiming** mechanisms.

## Key Features

* **Automated Royalty Distribution:** Ensures fair sharing of sales and secondary royalties among creators and contributors.
* **Primary and Secondary Sales:** Handles direct sales and secondary transactions with built-in royalty logic.
* **Collaborative Work Support:** Allows multiple contributors to share revenue based on percentage allocations.
* **NFT Integration:** Supports linking an external NFT contract to represent each artwork.
* **Transparent Record-Keeping:** Every sale, royalty payment, and contributor share is stored immutably on-chain.
* **Royalties Claim System:** Contributors can claim accumulated royalties directly from the contract.
* **Creator Controls:** Only the creator can manage contributors, deactivate artworks, or link NFT contracts.

## Core Contract Components

### 1. Data Maps

* **`artworks`** – Stores artwork details such as title, description, creator, royalty percentage, and NFT linkage.
* **`contributors`** – Records contributor principals, assigned share percentages, and roles.
* **`royalty-distributions`** – Tracks total royalties distributed and the last distribution block.
* **`claimable-royalties`** – Maintains claimable royalty balances per contributor.
* **`secondary-sales`** – Logs secondary market sales, including seller, buyer, sale amount, and royalties.
* **`next-sale-id-counter`** – Keeps count of sales per artwork for tracking secondary transactions.

### 2. Data Variables

* **`next-artwork-id-counter`** – Tracks incremental artwork IDs.
* **`contract-owner-address`** – Defines the administrator (creator of the contract).

### 3. Key Public Functions

* **`register-artwork`** – Creates a new artwork record with its metadata and royalty rate.
* **`add-contributor` / `remove-contributor`** – Manages contributors and their percentage shares.
* **`link-nft-contract`** – Links an NFT smart contract to an artwork for provenance and trading.
* **`primary-sale`** – Handles the first sale of an artwork and distributes proceeds.
* **`record-secondary-sale`** – Records a resale transaction, deducts royalties, and logs distribution.
* **`claim-royalties`** – Allows contributors to claim their accumulated royalty earnings.
* **`deactivate-artwork` / `reactivate-artwork`** – Toggles artwork visibility and participation in sales.

### 4. Private Helper Functions

* **`distribute-primary-sale`** – Allocates primary sale funds among contributors based on share percentages.
* **`distribute-royalties`** – Allocates secondary sale royalties to eligible contributors.

### 5. Read-Only Functions

* **`get-artwork-details`** – Fetches complete metadata of an artwork.
* **`get-contributor-details`** – Returns role and share information for a contributor.
* **`get-claimable-royalties`** – Displays unclaimed royalties for a contributor.
* **`get-royalty-stats`** – Shows total royalties and the last distribution block.
* **`get-secondary-sale`** – Retrieves details of a specific secondary sale.
* **`get-total-artworks`** – Returns the total number of artworks registered.

## Validation and Security

* **Access Control:** Only the creator can modify contributors or deactivate artworks.
* **Percentage Validation:** Ensures share and royalty percentages do not exceed defined limits.
* **Funds Validation:** Verifies that the buyer has sufficient balance for primary and secondary sales.
* **Immutable Records:** Artwork data, contributor details, and royalty logs are stored permanently on-chain.

## Workflow Summary

1. **Registration:** Creator registers an artwork and automatically becomes the primary contributor.
2. **Collaboration:** Additional contributors can be added with custom roles and share allocations.
3. **NFT Linking:** The artwork can be linked to an NFT smart contract for digital proof of ownership.
4. **Primary Sale:** The first sale is conducted, and proceeds are distributed among contributors.
5. **Secondary Sales:** Subsequent resales trigger automatic royalty deductions and distribution.
6. **Royalty Claiming:** Contributors withdraw their accumulated royalties via `claim-royalties`.

## Summary

**Musemint** establishes a transparent and automated royalty ecosystem for digital art. It ensures fair compensation across the creative chain—covering creators, collaborators, and contributors—through an on-chain distribution model that guarantees traceability, fairness, and efficiency in every transaction.
