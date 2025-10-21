;; Environmental Conservation Funding Platform Smart Contract
;; A decentralized platform for creating, funding, and tracking environmental conservation projects
;; Enables transparent milestone tracking, community voting, and impact measurement
;; Supports multiple conservation types: wildlife, forest, marine, climate, and biodiversity

;; Contract owner address stored at deployment
(define-constant contract-owner tx-sender)

;; Error codes for contract operations
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-CONTRACT-ALREADY-INITIALIZED (err u101))
(define-constant ERR-CONTRACT-NOT-INITIALIZED (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-PROJECT-ALREADY-EXISTS (err u105))
(define-constant ERR-PROJECT-NOT-FOUND (err u106))
(define-constant ERR-UNAUTHORIZED-PROJECT-ACTION (err u107))
(define-constant ERR-MILESTONE-ALREADY-COMPLETED (err u108))
(define-constant ERR-MILESTONE-NOT-FOUND (err u109))
(define-constant ERR-INVALID-DEADLINE (err u110))
(define-constant ERR-VOTING-PERIOD-ENDED (err u111))
(define-constant ERR-DUPLICATE-VOTE (err u112))
(define-constant ERR-PROJECT-INACTIVE (err u113))

;; Supported conservation project categories
(define-constant conservation-categories 
    (list 
        "wildlife"
        "forest"
        "marine"
        "climate"
        "biodiversity"
    )
)

;; Core project information storage
(define-map conservation-projects
    { project-identifier: uint }
    {
        project-creator: principal,
        project-title: (string-ascii 50),
        project-description: (string-ascii 500),
        project-location: (string-ascii 100),
        conservation-category: (string-ascii 20),
        target-funding-amount: uint,
        accumulated-funding: uint,
        current-status: (string-ascii 20),
        verification-approved: bool,
        creation-block-height: uint,
        expiration-block-height: uint,
        total-impact-score: uint,
        community-vote-tally: uint,
        milestones-achieved: uint
    }
)

;; Individual donor contribution tracking
(define-map contributor-records
    { project-identifier: uint, contributor-address: principal }
    { 
        total-contributed: uint,
        most-recent-contribution-block: uint,
        contribution-frequency: uint,
        incentive-rewards-claimed: bool
    }
)

;; Authorized project verifiers registry
(define-map verified-reviewers principal bool)

;; Project milestone definitions and progress
(define-map project-milestones
    { project-identifier: uint, milestone-number: uint }
    {
        milestone-description: (string-ascii 200),
        target-completion-block: uint,
        completion-status: bool,
        verification-evidence: (buff 32),
        verified-by: (optional principal)
    }
)

;; Community governance voting records
(define-map governance-votes
    { project-identifier: uint, participant-address: principal }
    {
        staked-token-amount: uint,
        voting-block-height: uint,
        vote-selection: (string-ascii 10)
    }
)

;; Measurable environmental impact metrics
(define-map impact-measurements
    { project-identifier: uint }
    {
        trees-planted-or-protected: uint,
        hectares-under-protection: uint,
        carbon-offset-tons: uint,
        species-protected-count: uint,
        community-members-benefited: uint
    }
)

;; Auto-incrementing project ID counter
(define-data-var next-available-project-id uint u0)

;; Total number of projects created
(define-data-var total-projects-created uint u0)

;; Contract initialization status flag
(define-data-var platform-operational bool false)

;; Minimum token stake for project creation
(define-data-var minimum-stake-tokens uint u100)

;; Voting window duration in blocks
(define-data-var voting-window-blocks uint u1440)

;; Activates the conservation platform contract
(define-public (initialize-platform)
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (not (var-get platform-operational)) ERR-CONTRACT-ALREADY-INITIALIZED)
        (var-set platform-operational true)
        (ok true)
    )
)

;; Updates the minimum stake requirement for creating projects
(define-public (update-minimum-stake (new-stake-amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> new-stake-amount u0) ERR-INVALID-AMOUNT)
        (var-set minimum-stake-tokens new-stake-amount)
        (ok true)
    )
)

;; Creates a new conservation project on the platform
(define-public (create-conservation-project 
    (title (string-ascii 50))
    (description (string-ascii 500))
    (location (string-ascii 100))
    (category (string-ascii 20))
    (funding-target uint)
    (project-duration-blocks uint))
    (let
        (
            (new-project-id (+ (var-get next-available-project-id) u1))
            (calculated-end-block (+ block-height project-duration-blocks))
        )
        (asserts! (> funding-target u0) ERR-INVALID-AMOUNT)
        (asserts! (> project-duration-blocks u0) ERR-INVALID-DEADLINE)
        
        ;; Transfer stake from creator to contract
        (try! (stx-transfer? (var-get minimum-stake-tokens) tx-sender (as-contract tx-sender)))
        
        (map-set conservation-projects
            { project-identifier: new-project-id }
            {
                project-creator: tx-sender,
                project-title: title,
                project-description: description,
                project-location: location,
                conservation-category: category,
                target-funding-amount: funding-target,
                accumulated-funding: u0,
                current-status: "active",
                verification-approved: false,
                creation-block-height: block-height,
                expiration-block-height: calculated-end-block,
                total-impact-score: u0,
                community-vote-tally: u0,
                milestones-achieved: u0
            }
        )
        (var-set next-available-project-id new-project-id)
        (var-set total-projects-created (+ (var-get total-projects-created) u1))
        (ok new-project-id)
    )
)

;; Defines a new milestone for an existing project
(define-public (define-project-milestone 
    (project-id uint)
    (milestone-details (string-ascii 200))
    (completion-deadline-block uint))
    (let
        (
            (project-data (unwrap! (map-get? conservation-projects { project-identifier: project-id }) ERR-PROJECT-NOT-FOUND))
            (current-milestone-count (get milestones-achieved project-data))
        )
        (asserts! (is-eq (get project-creator project-data) tx-sender) ERR-UNAUTHORIZED-PROJECT-ACTION)
        (asserts! (> completion-deadline-block block-height) ERR-INVALID-DEADLINE)
        
        (map-set project-milestones
            { project-identifier: project-id, milestone-number: current-milestone-count }
            {
                milestone-description: milestone-details,
                target-completion-block: completion-deadline-block,
                completion-status: false,
                verification-evidence: 0x,
                verified-by: none
            }
        )
        (ok true)
    )
)

;; Marks a milestone as completed with verification evidence
(define-public (complete-project-milestone 
    (project-id uint)
    (milestone-id uint)
    (evidence-hash (buff 32)))
    (let
        (
            (project-data (unwrap! (map-get? conservation-projects { project-identifier: project-id }) ERR-PROJECT-NOT-FOUND))
            (milestone-data (unwrap! (map-get? project-milestones { project-identifier: project-id, milestone-number: milestone-id }) ERR-MILESTONE-NOT-FOUND))
        )
        (asserts! (is-eq (get project-creator project-data) tx-sender) ERR-UNAUTHORIZED-PROJECT-ACTION)
        (asserts! (not (get completion-status milestone-data)) ERR-MILESTONE-ALREADY-COMPLETED)
        
        (map-set project-milestones
            { project-identifier: project-id, milestone-number: milestone-id }
            (merge milestone-data {
                completion-status: true,
                verification-evidence: evidence-hash
            })
        )
        
        (map-set conservation-projects
            { project-identifier: project-id }
            (merge project-data {
                milestones-achieved: (+ (get milestones-achieved project-data) u1)
            })
        )
        (ok true)
    )
)

;; Allows community members to vote on projects by staking tokens
(define-public (submit-project-vote 
    (project-id uint)
    (voting-stake uint)
    (vote-decision (string-ascii 10)))
    (let
        (
            (project-data (unwrap! (map-get? conservation-projects { project-identifier: project-id }) ERR-PROJECT-NOT-FOUND))
            (previous-vote (map-get? governance-votes { project-identifier: project-id, participant-address: tx-sender }))
        )
        (asserts! (is-eq (get current-status project-data) "active") ERR-PROJECT-INACTIVE)
        (asserts! (is-none previous-vote) ERR-DUPLICATE-VOTE)
        (asserts! (>= (- (get expiration-block-height project-data) block-height) (var-get voting-window-blocks)) ERR-VOTING-PERIOD-ENDED)
        (asserts! (> voting-stake u0) ERR-INVALID-AMOUNT)
        
        ;; Transfer voting stake to contract
        (try! (stx-transfer? voting-stake tx-sender (as-contract tx-sender)))
        
        (map-set governance-votes
            { project-identifier: project-id, participant-address: tx-sender }
            {
                staked-token-amount: voting-stake,
                voting-block-height: block-height,
                vote-selection: vote-decision
            }
        )
        
        (map-set conservation-projects
            { project-identifier: project-id }
            (merge project-data {
                community-vote-tally: (+ (get community-vote-tally project-data) u1)
            })
        )
        (ok true)
    )
)

;; Records verified environmental impact metrics for a project
(define-public (register-environmental-impact
    (project-id uint)
    (trees-count uint)
    (protected-hectares uint)
    (carbon-tons uint)
    (species-count uint)
    (beneficiary-count uint))
    (let
        (
            (project-data (unwrap! (map-get? conservation-projects { project-identifier: project-id }) ERR-PROJECT-NOT-FOUND))
        )
        (asserts! (is-eq (get project-creator project-data) tx-sender) ERR-UNAUTHORIZED-PROJECT-ACTION)
        (asserts! (>= trees-count u0) ERR-INVALID-AMOUNT)
        (asserts! (>= protected-hectares u0) ERR-INVALID-AMOUNT)
        (asserts! (>= carbon-tons u0) ERR-INVALID-AMOUNT)
        (asserts! (>= species-count u0) ERR-INVALID-AMOUNT)
        (asserts! (>= beneficiary-count u0) ERR-INVALID-AMOUNT)
        
        (map-set impact-measurements
            { project-identifier: project-id }
            {
                trees-planted-or-protected: trees-count,
                hectares-under-protection: protected-hectares,
                carbon-offset-tons: carbon-tons,
                species-protected-count: species-count,
                community-members-benefited: beneficiary-count
            }
        )
        
        (map-set conservation-projects
            { project-identifier: project-id }
            (merge project-data {
                total-impact-score: (+ trees-count protected-hectares carbon-tons species-count beneficiary-count)
            })
        )
        (ok true)
    )
)

;; Retrieves environmental impact data for a specific project
(define-read-only (fetch-impact-metrics (project-id uint))
    (map-get? impact-measurements { project-identifier: project-id })
)

;; Retrieves milestone information for a specific project
(define-read-only (fetch-milestone-info (project-id uint) (milestone-id uint))
    (map-get? project-milestones { project-identifier: project-id, milestone-number: milestone-id })
)

;; Retrieves voting information for a participant on a project
(define-read-only (fetch-vote-record (project-id uint) (voter-address principal))
    (map-get? governance-votes { project-identifier: project-id, participant-address: voter-address })
)

;; Calculates and returns project performance statistics
(define-read-only (calculate-project-performance (project-id uint))
    (match (map-get? conservation-projects { project-identifier: project-id })
        project-data (ok {
            funding-percentage: (/ (* (get accumulated-funding project-data) u100) (get target-funding-amount project-data)),
            milestone-completion-percentage: (/ (* (get milestones-achieved project-data) u100) u5),
            aggregate-impact-score: (get total-impact-score project-data),
            total-community-votes: (get community-vote-tally project-data)
        })
        ERR-PROJECT-NOT-FOUND
    )
)

;; Provides timeline and progress statistics for a project
(define-read-only (fetch-project-timeline (project-id uint))
    (match (map-get? conservation-projects { project-identifier: project-id })
        project-data (ok {
            days-remaining: (/ (- (get expiration-block-height project-data) block-height) u144),
            unique-contributors: (get community-vote-tally project-data),
            measured-impact: (get total-impact-score project-data),
            completed-milestones: (get milestones-achieved project-data)
        })
        ERR-PROJECT-NOT-FOUND
    )
)