;; Preservia - Heritage Preservation DAO
;; A DAO for tokenizing and preserving cultural heritage sites and artifacts

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-proposal-closed (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-proposal-active (err u107))
(define-constant err-proposal-not-passed (err u108))
(define-constant err-invalid-input (err u109))

;; Data structures for heritage sites and artifacts
(define-map heritage-assets
  { asset-id: uint }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    location: (string-ascii 100),
    creation-date: uint,
    cultural-significance: (string-utf8 500),
    total-funding-needed: uint,
    current-funding: uint,
    preservation-status: (string-ascii 20),
    curator: principal,
    metadata-url: (optional (string-ascii 256))
  }
)

;; Membership tokens using SIP-010 FT standard (simplified here)
(define-fungible-token preservia-token)

;; Initial token supply
(define-data-var token-supply uint u10000000)

;; Proposal structure for preservation initiatives
(define-map proposals
  { proposal-id: uint }
  {
    asset-id: uint,
    title: (string-ascii 100),
    description: (string-utf8 1000),
    proposed-by: principal,
    funding-amount: uint,
    preservation-plan: (string-utf8 1000),
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 20),  ;; "active", "passed", "rejected", "executed"
    deadline: uint,
    execution-date: (optional uint)
  }
)

;; Tracking members who voted on proposals
(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { voted: bool, vote-amount: uint, vote-direction: bool }  ;; true for yes, false for no
)

;; Track asset ownership shares
(define-map asset-ownership
  { asset-id: uint, owner: principal }
  { shares: uint }
)

;; Counters for IDs
(define-data-var next-asset-id uint u1)
(define-data-var next-proposal-id uint u1)

;; Initialize the contract with tokens to the contract owner
(ft-mint? preservia-token (var-get token-supply) contract-owner)

;; Helper function to validate string inputs
(define-private (validate-string-input (input (string-ascii 100)))
  (and (not (is-eq input "")) (< (len input) u100)))

;; Helper function to validate uint inputs
(define-private (validate-uint-input (input uint))
  (> input u0))

;; Admin functions

;; Add a new heritage asset to the registry
(define-public (register-heritage-asset 
                  (name (string-ascii 100))
                  (description (string-utf8 500))
                  (location (string-ascii 100))
                  (creation-date uint)
                  (cultural-significance (string-utf8 500))
                  (total-funding-needed uint)
                  (preservation-status (string-ascii 20))
                  (metadata-url (optional (string-ascii 256))))
  (let ((asset-id (var-get next-asset-id))
        (validated-name (validate-string-input name))
        (validated-location (validate-string-input location))
        (validated-status (validate-string-input preservation-status))
        (validated-funding (validate-uint-input total-funding-needed))
        (validated-date (validate-uint-input creation-date)))
    
    ;; Validate inputs
    (asserts! validated-name err-invalid-input)
    (asserts! validated-location err-invalid-input)
    (asserts! validated-status err-invalid-input)
    (asserts! validated-funding err-invalid-input)
    (asserts! validated-date err-invalid-input)
    (asserts! (> (len description) u0) err-invalid-input)
    (asserts! (> (len cultural-significance) u0) err-invalid-input)
    
    ;; Check authorization
    (asserts! (or (is-eq tx-sender contract-owner)
                (>= (ft-get-balance preservia-token tx-sender) u1000))
            err-unauthorized)
    
    (map-insert heritage-assets 
      { asset-id: asset-id }
      {
        name: name,
        description: description,
        location: location,
        creation-date: creation-date,
        cultural-significance: cultural-significance,
        total-funding-needed: total-funding-needed,
        current-funding: u0,
        preservation-status: preservation-status,
        curator: tx-sender,
        metadata-url: metadata-url
      })
    
    ;; Give initial shares to the registrant
    (map-insert asset-ownership
      { asset-id: asset-id, owner: tx-sender }
      { shares: u100 })
    
    ;; Increment the asset ID counter
    (var-set next-asset-id (+ asset-id u1))
    
    (ok asset-id)))

;; Create a new proposal for a preservation initiative
(define-public (create-proposal 
                  (asset-id uint)
                  (title (string-ascii 100))
                  (description (string-utf8 1000))
                  (funding-amount uint)
                  (preservation-plan (string-utf8 1000))
                  (deadline uint))
  (let ((proposal-id (var-get next-proposal-id))
        (validated-title (validate-string-input title))
        (validated-funding (validate-uint-input funding-amount))
        (validated-deadline (> deadline block-height)))
    
    ;; Validate inputs
    (asserts! validated-title err-invalid-input)
    (asserts! validated-funding err-invalid-input)
    (asserts! validated-deadline err-proposal-closed)
    (asserts! (> (len description) u0) err-invalid-input)
    (asserts! (> (len preservation-plan) u0) err-invalid-input)
    
    ;; Ensure asset exists
    (asserts! (is-some (map-get? heritage-assets { asset-id: asset-id })) err-not-found)
    
    ;; Require minimum token stake to create a proposal
    (asserts! (>= (ft-get-balance preservia-token tx-sender) u500) err-unauthorized)
    
    (map-insert proposals
      { proposal-id: proposal-id }
      {
        asset-id: asset-id,
        title: title,
        description: description, 
        proposed-by: tx-sender,
        funding-amount: funding-amount,
        preservation-plan: preservation-plan,
        votes-for: u0,
        votes-against: u0,
        status: "active",
        deadline: deadline,
        execution-date: none
      })
    
    ;; Increment the proposal ID counter
    (var-set next-proposal-id (+ proposal-id u1))
    
    (ok proposal-id)))

;; Vote on a proposal (yes or no)
(define-public (vote-on-proposal (proposal-id uint) (vote-direction bool) (vote-amount uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    (voter-balance (ft-get-balance preservia-token tx-sender))
  )
    ;; Validate inputs
    (asserts! (validate-uint-input proposal-id) err-invalid-input)
    (asserts! (validate-uint-input vote-amount) err-invalid-input)
    
    ;; Check if the proposal is still active
    (asserts! (is-eq (get status proposal) "active") err-proposal-closed)
    (asserts! (< block-height (get deadline proposal)) err-proposal-closed)
    
    ;; Check if the user has enough tokens to vote
    (asserts! (>= voter-balance vote-amount) err-insufficient-funds)
    
    ;; Check if user has already voted
    (asserts! (is-none (map-get? proposal-votes { proposal-id: proposal-id, voter: tx-sender }))
              err-already-voted)
    
    ;; Record the vote
    (map-insert proposal-votes
      { proposal-id: proposal-id, voter: tx-sender }
      { voted: true, vote-amount: vote-amount, vote-direction: vote-direction })
    
    ;; Update the vote counts
    (if vote-direction
      (map-set proposals { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) vote-amount) }))
      (map-set proposals { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) vote-amount) }))
    )
    
    ;; Lock the voting tokens and return the result
    (unwrap! (ft-transfer? preservia-token vote-amount tx-sender (as-contract tx-sender))
             err-insufficient-funds)
    
    (ok true)
  ))

;; Finalize a proposal after its deadline
(define-public (finalize-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
  )
    ;; Validate inputs
    (asserts! (validate-uint-input proposal-id) err-invalid-input)
    
    ;; Ensure the proposal deadline has passed and it's still active
    (asserts! (>= block-height (get deadline proposal)) err-proposal-active)
    (asserts! (is-eq (get status proposal) "active") err-proposal-closed)
    
    ;; Determine if the proposal passed (more votes for than against)
    (if (> (get votes-for proposal) (get votes-against proposal))
      (begin
        (map-set proposals { proposal-id: proposal-id }
          (merge proposal { status: "passed" }))
        (ok true))
      (begin
        (map-set proposals { proposal-id: proposal-id }
          (merge proposal { status: "rejected" }))
        
        ;; Return tokens to voters if rejected (simplified, would need loop in practice)
        (ok false)))
  ))

;; Execute a passed proposal to fund preservation efforts
(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    (asset (unwrap! (map-get? heritage-assets { asset-id: (get asset-id proposal) }) err-not-found))
  )
    ;; Validate inputs
    (asserts! (validate-uint-input proposal-id) err-invalid-input)
    
    ;; Ensure the proposal has passed
    (asserts! (is-eq (get status proposal) "passed") err-proposal-not-passed)
    
    ;; Update the asset's current funding and status
    (map-set heritage-assets { asset-id: (get asset-id proposal) }
      (merge asset { 
        current-funding: (+ (get current-funding asset) (get funding-amount proposal)),
        preservation-status: "in-progress"
      }))
    
    ;; Mark the proposal as executed
    (map-set proposals { proposal-id: proposal-id }
      (merge proposal { 
        status: "executed",
        execution-date: (some block-height)
      }))
    
    ;; Grant ownership shares to all who voted "yes" proportional to their vote
    ;; This would require a loop through all voters in practice
    
    (ok true)
  ))

;; Donate funds directly to a heritage asset
(define-public (donate-to-heritage (asset-id uint) (amount uint))
  (let (
    (asset (unwrap! (map-get? heritage-assets { asset-id: asset-id }) err-not-found))
    (donor-shares (default-to { shares: u0 } 
                    (map-get? asset-ownership { asset-id: asset-id, owner: tx-sender })))
  )
    ;; Validate inputs
    (asserts! (validate-uint-input asset-id) err-invalid-input)
    (asserts! (validate-uint-input amount) err-invalid-input)
    
    ;; Check if the user has enough tokens
    (asserts! (>= (ft-get-balance preservia-token tx-sender) amount) err-insufficient-funds)
    
    ;; Transfer tokens to the contract
    (unwrap! (ft-transfer? preservia-token amount tx-sender (as-contract tx-sender))
             err-insufficient-funds)
    
    ;; Update the asset's current funding
    (map-set heritage-assets { asset-id: asset-id }
      (merge asset { current-funding: (+ (get current-funding asset) amount) }))
    
    ;; Grant ownership shares proportional to donation
    (map-set asset-ownership
      { asset-id: asset-id, owner: tx-sender }
      { shares: (+ (get shares donor-shares) (/ amount u10)) })
    
    (ok true)
  ))

;; Read-only functions

;; Get asset details
(define-read-only (get-heritage-asset (asset-id uint))
  (map-get? heritage-assets { asset-id: asset-id }))

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id }))

;; Get user's ownership shares for an asset
(define-read-only (get-ownership-shares (asset-id uint) (owner principal))
  (default-to { shares: u0 } 
    (map-get? asset-ownership { asset-id: asset-id, owner: owner })))

;; Check if a user has voted on a proposal
(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })))

;; Get total assets registered
(define-read-only (get-total-assets)
  (- (var-get next-asset-id) u1))

;; Get total proposals created
(define-read-only (get-total-proposals)
  (- (var-get next-proposal-id) u1))