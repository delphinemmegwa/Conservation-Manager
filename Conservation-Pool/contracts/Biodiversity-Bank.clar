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
(define-constant ERR-INVALID-CATEGORY (err u114))
(define-constant ERR-INVALID-STRING-INPUT (err u115))
(define-constant ERR-INVALID-VOTE-DECISION (err u116))

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

;; Valid vote decisions
(define-constant valid-vote-options
    (list
        "approve"
        "reject"
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

;; Helper function to validate category
(define-private (is-valid-category (category (string-ascii 20)))
    (or
        (is-eq category "wildlife")
        (or (is-eq category "forest")
        (or (is-eq category "marine")
        (or (is-eq category "climate")
            (is-eq category "biodiversity")))))
)

;; Helper function to validate vote decision
(define-private (is-valid-vote (vote (string-ascii 10)))
    (or
        (is-eq vote "approve")
        (is-eq vote "reject")
    )
)

;; Helper function to validate string is not empty
(define-private (is-non-empty-string (str (string-ascii 500)))
    (> (len str) u0)
)

;; Helper function to validate project exists and return data
(define-private (validate-project-exists (project-id uint))
    (let
        (
            (validated-id (if (<= project-id (var-get next-available-project-id)) project-id u0))
        )
        (ok (unwrap! (map-get? conservation-projects { project-identifier: validated-id }) ERR-PROJECT-NOT-FOUND))
    )
)

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
        ;; Input validation
        (asserts! (is-non-empty-string title) ERR-INVALID-STRING-INPUT)
        (asserts! (is-non-empty-string description) ERR-INVALID-STRING-INPUT)
        (asserts! (is-non-empty-string location) ERR-INVALID-STRING-INPUT)
        (asserts! (is-valid-category category) ERR-INVALID-CATEGORY)
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
            (validated-project-id (if (<= project-id (var-get next-available-project-id)) project-id u0))
            (project-data (try! (validate-project-exists validated-project-id)))
            (current-milestone-count (get milestones-achieved project-data))
        )
        ;; Input validation
        (asserts! (is-non-empty-string milestone-details) ERR-INVALID-STRING-INPUT)
        (asserts! (is-eq (get project-creator project-data) tx-sender) ERR-UNAUTHORIZED-PROJECT-ACTION)
        (asserts! (> completion-deadline-block block-height) ERR-INVALID-DEADLINE)
        
        (map-set project-milestones
            { project-identifier: validated-project-id, milestone-number: current-milestone-count }
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
            (validated-project-id (if (<= project-id (var-get next-available-project-id)) project-id u0))
            (project-data (try! (validate-project-exists validated-project-id)))
            (validated-milestone-id (if (<= milestone-id (get milestones-achieved project-data)) milestone-id u0))
            (milestone-data (unwrap! (map-get? project-milestones { project-identifier: validated-project-id, milestone-number: validated-milestone-id }) ERR-MILESTONE-NOT-FOUND))
        )
        ;; Validation
        (asserts! (is-eq (get project-creator project-data) tx-sender) ERR-UNAUTHORIZED-PROJECT-ACTION)
        (asserts! (not (get completion-status milestone-data)) ERR-MILESTONE-ALREADY-COMPLETED)
        
        (map-set project-milestones
            { project-identifier: validated-project-id, milestone-number: validated-milestone-id }
            (merge milestone-data {
                completion-status: true,
                verification-evidence: evidence-hash
            })
        )
        
        (map-set conservation-projects
            { project-identifier: validated-project-id }
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
            (validated-project-id (if (<= project-id (var-get next-available-project-id)) project-id u0))
            (project-data (try! (validate-project-exists validated-project-id)))
            (previous-vote (map-get? governance-votes { project-identifier: validated-project-id, participant-address: tx-sender }))
        )
        ;; Input validation
        (asserts! (is-valid-vote vote-decision) ERR-INVALID-VOTE-DECISION)
        (asserts! (is-eq (get current-status project-data) "active") ERR-PROJECT-INACTIVE)
        (asserts! (is-none previous-vote) ERR-DUPLICATE-VOTE)
        (asserts! (>= (- (get expiration-block-height project-data) block-height) (var-get voting-window-blocks)) ERR-VOTING-PERIOD-ENDED)
        (asserts! (> voting-stake u0) ERR-INVALID-AMOUNT)
        
        ;; Transfer voting stake to contract
        (try! (stx-transfer? voting-stake tx-sender (as-contract tx-sender)))
        
        (map-set governance-votes
            { project-identifier: validated-project-id, participant-address: tx-sender }
            {
                staked-token-amount: voting-stake,
                voting-block-height: block-height,
                vote-selection: vote-decision
            }
        )
        
        (map-set conservation-projects
            { project-identifier: validated-project-id }
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
            (validated-project-id (if (<= project-id (var-get next-available-project-id)) project-id u0))
            (project-data (try! (validate-project-exists validated-project-id)))
            ;; Validate and sanitize inputs
            (validated-trees (if (<= trees-count u1000000000) trees-count u0))
            (validated-hectares (if (<= protected-hectares u1000000000) protected-hectares u0))
            (validated-carbon (if (<= carbon-tons u1000000000) carbon-tons u0))
            (validated-species (if (<= species-count u1000000) species-count u0))
            (validated-beneficiaries (if (<= beneficiary-count u1000000000) beneficiary-count u0))
        )
        ;; Validation
        (asserts! (is-eq (get project-creator project-data) tx-sender) ERR-UNAUTHORIZED-PROJECT-ACTION)
        
        (map-set impact-measurements
            { project-identifier: validated-project-id }
            {
                trees-planted-or-protected: validated-trees,
                hectares-under-protection: validated-hectares,
                carbon-offset-tons: validated-carbon,
                species-protected-count: validated-species,
                community-members-benefited: validated-beneficiaries
            }
        )
        
        (map-set conservation-projects
            { project-identifier: validated-project-id }
            (merge project-data {
                total-impact-score: (+ validated-trees validated-hectares validated-carbon validated-species validated-beneficiaries)
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