;; Title: Token Subscription Manager
;; Description: Handles recurring payments for services using SIP-010 tokens.

(use-trait t-sip010 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-SUBBED (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant BLOCKS-PER-MONTH u4320) ;; ~30 days

;; Data Maps
(define-map subscriptions
    { user: principal, service: principal }
    {
        amount: uint,
        token: principal,
        last-payment: uint,
        next-payment: uint,
        active: bool
    }
)

;; Public Functions
(define-public (subscribe (service principal) (amount uint) (token <t-sip010>))
    (begin
        (asserts! (is-none (map-get? subscriptions { user: tx-sender, service: service })) ERR-ALREADY-SUBBED)
        (try! (contract-call? token transfer amount tx-sender service none))
        (ok (map-set subscriptions { user: tx-sender, service: service } {
            amount: amount,
            token: (contract-of token),
            last-payment: stacks-block-height,
            next-payment: (+ stacks-block-height BLOCKS-PER-MONTH),
            active: true
        }))
    )
)

(define-public (process-payment (user principal) (token <t-sip010>))
    (let
        ((sub (unwrap! (map-get? subscriptions { user: user, service: tx-sender }) ERR-NOT-AUTHORIZED)))
        (asserts! (get active sub) ERR-NOT-AUTHORIZED)
        (asserts! (>= stacks-block-height (get next-payment sub)) (err u103))
        (asserts! (is-eq (contract-of token) (get token sub)) (err u104))
        
        (try! (contract-call? token transfer (get amount sub) user tx-sender none))
        (ok (map-set subscriptions { user: user, service: tx-sender } (merge sub {
            last-payment: stacks-block-height,
            next-payment: (+ stacks-block-height BLOCKS-PER-MONTH)
        })))
    )
)

(define-public (cancel-subscription (service principal))
    (let
        ((sub (unwrap! (map-get? subscriptions { user: tx-sender, service: service }) ERR-NOT-AUTHORIZED)))
        (ok (map-set subscriptions { user: tx-sender, service: service } (merge sub { active: false })))
    )
)
