# Environmental Conservation Funding Platform

A decentralized smart contract platform built on Stacks blockchain for creating, funding, and tracking environmental conservation projects with transparent milestone management and community governance.

## Overview

This smart contract enables transparent funding and management of environmental conservation initiatives across multiple categories including wildlife protection, forest conservation, marine ecosystems, climate action, and biodiversity preservation.

## Features

- **Project Creation**: Launch conservation projects with detailed descriptions and funding goals
- **Milestone Tracking**: Define and verify project milestones with cryptographic evidence
- **Community Voting**: Token-based governance allowing community participation in project decisions
- **Impact Measurement**: Track quantifiable environmental outcomes including trees planted, hectares protected, carbon offset, and species protected
- **Multi-Category Support**: Support for wildlife, forest, marine, climate, and biodiversity projects
- **Transparent Funding**: On-chain tracking of all contributions and fund allocation

## Supported Conservation Categories

- Wildlife
- Forest
- Marine
- Climate
- Biodiversity

## Contract Architecture

### Core Data Structures

**Conservation Projects**
- Project metadata (title, description, location, category)
- Funding information (target amount, accumulated funds)
- Status tracking (active/inactive, verification status)
- Timeline management (creation block, expiration block)
- Performance metrics (impact score, votes, milestones)

**Contributor Records**
- Individual contribution tracking per project
- Contribution history and frequency
- Reward claim status

**Project Milestones**
- Milestone descriptions and deadlines
- Completion status and verification evidence
- Verifier information

**Governance Votes**
- Token-staked voting records
- Vote decisions (approve/reject)
- Voting timestamps

**Impact Measurements**
- Trees planted or protected
- Hectares under protection
- Carbon offset in tons
- Species protected count
- Community members benefited

## Key Functions

### Administrative Functions

**initialize-platform**
```clarity
(initialize-platform)
```
Activates the platform contract. Only callable by contract owner.

**update-minimum-stake**
```clarity
(update-minimum-stake new-stake-amount)
```
Updates the minimum token stake required for project creation.

### Project Management

**create-conservation-project**
```clarity
(create-conservation-project 
    title 
    description 
    location 
    category 
    funding-target 
    project-duration-blocks)
```
Creates a new conservation project. Requires minimum stake transfer.

Parameters:
- title: Project name (max 50 characters)
- description: Detailed project description (max 500 characters)
- location: Geographic location (max 100 characters)
- category: Conservation type (wildlife/forest/marine/climate/biodiversity)
- funding-target: Target funding amount in micro-STX
- project-duration-blocks: Project duration in blockchain blocks

**define-project-milestone**
```clarity
(define-project-milestone 
    project-id 
    milestone-details 
    completion-deadline-block)
```
Defines a new milestone for an existing project. Only callable by project creator.

**complete-project-milestone**
```clarity
(complete-project-milestone 
    project-id 
    milestone-id 
    evidence-hash)
```
Marks a milestone as completed with cryptographic evidence. Only callable by project creator.

### Community Engagement

**submit-project-vote**
```clarity
(submit-project-vote 
    project-id 
    voting-stake 
    vote-decision)
```
Allows community members to vote on projects by staking tokens.

Vote decisions: "approve" or "reject"

**register-environmental-impact**
```clarity
(register-environmental-impact
    project-id
    trees-count
    protected-hectares
    carbon-tons
    species-count
    beneficiary-count)
```
Records verified environmental impact metrics. Only callable by project creator.

### Read-Only Functions

**fetch-impact-metrics**
```clarity
(fetch-impact-metrics project-id)
```
Retrieves environmental impact data for a project.

**fetch-milestone-info**
```clarity
(fetch-milestone-info project-id milestone-id)
```
Retrieves information about a specific milestone.

**fetch-vote-record**
```clarity
(fetch-vote-record project-id voter-address)
```
Retrieves voting information for a participant.

**calculate-project-performance**
```clarity
(calculate-project-performance project-id)
```
Returns project performance statistics including funding percentage, milestone completion, and impact scores.

**fetch-project-timeline**
```clarity
(fetch-project-timeline project-id)
```
Provides timeline and progress statistics for a project.

## Error Codes

- ERR-UNAUTHORIZED-ACCESS (100): Caller lacks required permissions
- ERR-CONTRACT-ALREADY-INITIALIZED (101): Contract already activated
- ERR-CONTRACT-NOT-INITIALIZED (102): Contract not yet activated
- ERR-INVALID-AMOUNT (103): Invalid token amount provided
- ERR-INSUFFICIENT-BALANCE (104): Insufficient token balance
- ERR-PROJECT-ALREADY-EXISTS (105): Project ID conflict
- ERR-PROJECT-NOT-FOUND (106): Project does not exist
- ERR-UNAUTHORIZED-PROJECT-ACTION (107): Not project creator
- ERR-MILESTONE-ALREADY-COMPLETED (108): Milestone already marked complete
- ERR-MILESTONE-NOT-FOUND (109): Milestone does not exist
- ERR-INVALID-DEADLINE (110): Invalid deadline specified
- ERR-VOTING-PERIOD-ENDED (111): Voting window closed
- ERR-DUPLICATE-VOTE (112): User already voted
- ERR-PROJECT-INACTIVE (113): Project not active
- ERR-INVALID-CATEGORY (114): Unsupported conservation category
- ERR-INVALID-STRING-INPUT (115): Empty string provided
- ERR-INVALID-VOTE-DECISION (116): Invalid vote option

## Configuration Parameters

- **Minimum Stake Tokens**: Default 100 micro-STX (configurable)
- **Voting Window Blocks**: Default 1440 blocks (configurable)
- **Block Time**: Approximately 10 minutes per block on Stacks

## Security Considerations

- All state-changing functions include comprehensive input validation
- Token transfers are atomic and use try! for automatic rollback on failure
- Project creators must stake tokens to create projects
- Milestone completion requires cryptographic evidence
- Duplicate voting is prevented
- Maximum value limits protect against overflow attacks

## Usage Examples

### Creating a Project

```clarity
(contract-call? .conservation-platform create-conservation-project
    "Amazon Rainforest Protection"
    "Protect 1000 hectares of Amazon rainforest through land acquisition and monitoring"
    "Amazon Basin, Brazil"
    "forest"
    u50000000000
    u144000)
```

### Submitting a Vote

```clarity
(contract-call? .conservation-platform submit-project-vote
    u1
    u1000
    "approve")
```

### Recording Impact

```clarity
(contract-call? .conservation-platform register-environmental-impact
    u1
    u5000
    u1000
    u2500
    u15
    u500)
```