;; Title: Multi-Signature Vault with Timelock
;; Description: A secure vault requiring multiple approvals and a waiting period for withdrawals.

(use-trait t-sip010 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-SIGNED (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-TIMELOCK-ACTIVE (err u103))
(define-constant TIMELOCK-DURATION u144) ;; ~24 hours in blocks

;; Data Vars
(define-data-var threshold u2)
(define-map owners principal bool)
(define-data-var owner-count u0)

;; Data Maps
(define-map proposals
    uint 
    {
        recipient: principal,
        amount: uint,
        token: (optional principal),
        proposer: principal,
        signatures: uint,
        created-at: uint,
        executed: bool
    }
)

(define-map voter-approvals { proposal-id: uint, voter: principal } bool)

(define-data-var proposal-nonce uint u0)

;; Protected Functions
(define-public (add-owner (new-owner principal))
    (begin
        (asserts! (default-to false (map-get? owners tx-sender)) ERR-NOT-AUTHORIZED)
        (map-set owners new-owner true)
        (var-set owner-count (+ (var-get owner-count) u1))
        (ok true)
    )
)

;; Core Functions
(define-public (propose-withdrawal (recipient principal) (amount uint) (token (optional principal)))
    (let
        ((id (var-get proposal-nonce)))
        (asserts! (default-to false (map-get? owners tx-sender)) ERR-NOT-AUTHORIZED)
        (map-set proposals id {
            recipient: recipient,
            amount: amount,
            token: token,
            proposer: tx-sender,
            signatures: u1,
            created-at: stacks-block-height,
            executed: false
        })
        (map-set voter-approvals { proposal-id: id, voter: tx-sender } true)
        (var-set proposal-nonce (+ id u1))
        (ok id)
    )
)

(define-public (approve-proposal (id uint))
    (let
        ((proposal (unwrap! (map-get? proposals id) ERR-NOT-FOUND)))
        (asserts! (default-to false (map-get? owners tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? voter-approvals { proposal-id: id, voter: tx-sender })) ERR-ALREADY-SIGNED)
        
        (map-set voter-approvals { proposal-id: id, voter: tx-sender } true)
        (map-set proposals id (merge proposal { signatures: (+ (get signatures proposal) u1) }))
        (ok true)
    )
)

(define-public (execute-proposal (id uint) (token-trait (optional <t-sip010>)))
    (let
        ((proposal (unwrap! (map-get? proposals id) ERR-NOT-FOUND)))
        (asserts! (>= (get signatures proposal) (var-get threshold)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get executed proposal)) ERR-ALREADY-SIGNED)
        (asserts! (>= stacks-block-height (+ (get created-at proposal) TIMELOCK-DURATION)) ERR-TIMELOCK-ACTIVE)
        
        (map-set proposals id (merge proposal { executed: true }))
        
        (match (get token proposal)
            token-addr (match token-trait
                trait (contract-call? trait transfer (get amount proposal) (as-contract tx-sender) (get recipient proposal) none)
                (err u404)
            )
            (as-contract (stx-transfer? (get amount proposal) tx-sender (get recipient proposal)))
        )
    )
)

;; Init
(map-set owners tx-sender true)
(var-set owner-count u1)
