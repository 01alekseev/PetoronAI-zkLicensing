# PetoronAI-zkLicensing

Official licensing framework for PetoronAI.

PetoronAI-zkLicensing provides a structured workflow for license commitment generation, proof generation, license payment, and on-chain license activation.

---

## Overview

PetoronAI-zkLicensing consists of three primary components:

1. License Creation
2. License Proof Generation
3. License Payment and Activation

The system allows organizations, startups, governments, ministries, public institutions, and other authorized entities to generate a cryptographic license artifact, generate a corresponding proof, publish a commitment on-chain, and activate a commercial PetoronAI license through the official license contract.

---

## License Creation

The Create License interface is used to generate a license commitment and a binary `.pnote` license artifact.

Required inputs:

- Net income for the year
- Official supporting financial document
- Licensed contract address (The address is listed below)

Workflow:

1. Enter the required financial value.
2. Attach the official supporting document.
3. Specify the licensed contract address.
4. Generate the license artifact.
5. Save the generated `.pnote` file.
6. Copy the generated commitment.

Generated `.pnote` artifacts contain:

- Income fingerprint
- Source document fingerprint
- Contract address
- Commitment data

The original supporting document and generated `.pnote` file should be retained by the Licensee.

Loss of either file may prevent future proof generation.

---

## License Proof Generation

The Verify License interface generates a local license proof.

Required inputs:

- Original `.pnote` file
- Original supporting document used during license creation

Workflow:

1. Load the `.pnote` file.
2. Load the original supporting document.
3. Generate proof.
4. Copy generated proof.

Proof generation is only possible when:

- The uploaded document matches the fingerprint stored within the `.pnote`.
- The license artifact remains intact.
- The commitment data remains valid.

This prevents substitution of unrelated documentation.

---

## Official License Contract

Official PetoronAI Commercial License Smart Contract:

0x6BD1A8237b1620D11acB4520b3B2EeF13d7e6516

All commercial license payments and corresponding license commitments must be submitted to this contract.

A commercial license becomes effective upon successful receipt by the official license contract of:

- The required ETH payment
- The corresponding license commitment

No commercial license shall be deemed active prior to successful recording of both elements by the official license contract.

---

## PetoronAI Client Wallet

PetoronAI-zkLicensing includes a dedicated local client wallet.

The wallet is designed for commercial license payment workflows and commitment publication. Use of the client wallet is optional and provided solely as a convenience for local license payment workflows.

### Features

- Ethereum Mainnet RPC connection
- Custom RPC endpoint support
- Local private key operation
- Commitment submission
- License payment support
- Commitment verification
- Direct blockchain interaction
- Local transaction preparation

The wallet operates locally and does not require custody by any third party.

Users provide:

- Ethereum RPC endpoint
- Private key
- Commitment value

The wallet prepares and submits transactions directly to the blockchain.

---

## License Cost Determination

### Commercial Organizations

For commercial organizations, the license cost is determined using the organization's official annual net profit as documented in the submitted financial statement or equivalent official financial documentation.

The submitted document becomes part of the license commitment process.

### Startups

For startups that have not yet generated annual net profit, the license cost is determined using official projected revenue, projected annual profit, business forecast, investment memorandum, financial projection, or other officially prepared financial estimate.

The submitted document becomes part of the license commitment process.

### Governments and Public Institutions

For governments, ministries, municipalities, public agencies, state organizations, healthcare authorities, educational authorities, and other public institutions, the license cost is determined using officially allocated budgets relevant to the intended deployment area.

Examples include:

- Digitalization
- Information Technology
- Healthcare
- Education
- Infrastructure
- Research
- Public Services

Supporting budget documentation must be provided.

The submitted document becomes part of the license commitment process.

---

## Payment Conversion

After the applicable license cost has been determined, the Licensee independently converts the resulting amount into ETH using the current market exchange rate available at the time of payment.

The resulting ETH amount is then submitted to the official PetoronAI license contract together with the generated commitment.

The Licensee remains solely responsible for ensuring that the correct ETH amount is submitted.

---

## License Duration

Commercial licenses are granted for a period of one (1) year beginning from the date the ETH payment and corresponding commitment are successfully recorded by the official license contract.

The effective date is determined exclusively by the blockchain record associated with the official license contract.

---

## License Renewal

Upon expiration of a commercial license term, renewal requires:

1. Updated supporting documentation.
2. Updated financial information.
3. Generation of a new license artifact.
4. Generation of a new proof.
5. Calculation of the updated license cost.
6. Submission of a new commitment.
7. Submission of a new ETH payment.

Renewal is not automatic.

Each renewal period constitutes a new licensing cycle.

---

## Document Integrity Requirements

All license calculations rely upon official supporting documentation.

Submitted documentation must:

- Be authentic
- Be legally authorized
- Correspond to the represented financial information
- Remain available for future proof generation

PetoronAI-zkLicensing does not independently certify the accuracy of submitted financial information.

Responsibility for submitted information remains solely with the submitting entity.

---

## License Scope

PetoronAI-zkLicensing is an official component of the PetoronAI software ecosystem.

PetoronAI-zkLicensing may be distributed as a separate repository for organizational and deployment purposes while remaining subject to the PetoronAI licensing framework.

Use of PetoronAI-zkLicensing is governed by:

- PetoronAI Community License (PCL)
- PetoronAI Commercial License (PCL-C)

as applicable.

---

## Security Properties

- Binary license artifacts
- zkPetoron & PetoronHash2-based commitments
- Local proof generation
- On-chain commitment support
- Document fingerprint binding
- Contract binding
- Commitment integrity protection
- Tamper detection

---

## Proof Of License Ownership

The successful submission of ETH and a corresponding commitment to the official PetoronAI license contract does not, by itself, constitute proof of ownership of a valid PetoronAI Commercial License.

Proof of ownership of a commercial license requires possession of both:

* The original `.pnote` license artifact generated during license creation.
* The original supporting document used during license creation and commitment generation.

The ability to generate a valid license proof from the original `.pnote` file and the corresponding original supporting document constitutes the authoritative proof of ownership of the associated license commitment.

Accordingly, Licensees must securely retain and preserve:

* The original `.pnote` file.
* The original supporting document.

Licensees must not alter, modify, replace, corrupt, or destroy either file.

Loss, destruction, modification, corruption, or unavailability of either file may prevent generation of a valid license proof and may prevent the Licensee from demonstrating ownership of the associated license commitment and commercial license.

Responsibility for secure retention of these files rests solely with the Licensee.

---

## Disclaimer

PetoronAI-zkLicensing is provided solely as a licensing and commitment framework.

Nothing in this repository constitutes legal, accounting, tax, regulatory, investment, or financial advice.

Licensees remain solely responsible for the accuracy, legality, completeness, and authorization of all submitted documentation and financial information.

---

Petoron | Ivan Alekseev
