;; Title: On-Chain Reputation System
;; Description: Tracks user trust and reputation scores based on community actions and verified traits.

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-NOT-FOUND (err u101))
(define-constant CONTRACT-OWNER tx-sender)

;; Data Maps
(define-map user-reputation
    principal
    {
        score: int,
        voters: uint,
        last-updated: uint
    }
)

(define-map trusted-oracles principal bool)

;; Read-only Functions
(define-read-only (get-score (user principal))
    (ok (default-to { score: 0, voters: u0, last-updated: u0 } (map-get? user-reputation user)))
)

;; Public Functions
(define-public (set-oracle (oracle principal) (status bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-set trusted-oracles oracle status))
    )
)

(define-public (update-reputation (user principal) (score-delta int))
    (let
        ((current-data (unwrap! (get-score user) ERR-USER-NOT-FOUND)))
        (asserts! (default-to false (map-get? trusted-oracles tx-sender)) ERR-NOT-AUTHORIZED)
        (ok (map-set user-reputation user {
            score: (+ (get score current-data) score-delta),
            voters: (+ (get voters current-data) u1),
            last-updated: stacks-block-height
        }))
    )
)

(define-public (initialize-user)
    (begin
        (asserts! (is-none (map-get? user-reputation tx-sender)) (err u102))
        (ok (map-set user-reputation tx-sender {
            score: 0,
            voters: u0,
            last-updated: stacks-block-height
        }))
    )
)
