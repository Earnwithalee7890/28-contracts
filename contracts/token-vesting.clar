;; Title: Token Vesting Contract
;; Description: Releases tokens over time based on a cliff and linear schedule.

(use-trait t-sip010 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-VESTING-NOT-ACTIVE (err u101))

;; Data Maps
(define-map vesting-schedules
    principal
    {
        total-amount: uint,
        claimed-amount: uint,
        start-height: uint,
        cliff-height: uint,
        end-height: uint,
        token: principal
    }
)

;; Public Functions
(define-public (create-vesting-schedule 
    (beneficiary principal) 
    (amount uint) 
    (cliff-delta uint) 
    (duration uint) 
    (token <t-sip010>))
    (begin
        (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR-NOT-AUTHORIZED) ;; Example restriction
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
        (ok (map-set vesting-schedules beneficiary {
            total-amount: amount,
            claimed-amount: u0,
            start-height: stacks-block-height,
            cliff-height: (+ stacks-block-height cliff-delta),
            end-height: (+ stacks-block-height cliff-delta duration),
            token: (contract-of token)
        }))
    )
)

(define-public (claim-vested-tokens (token <t-sip010>))
    (let
        ((schedule (unwrap! (map-get? vesting-schedules tx-sender) ERR-VESTING-NOT-ACTIVE))
         (available (calculate-vested-amount tx-sender)))
        (asserts! (> available u0) (err u102))
        (asserts! (is-eq (contract-of token) (get token schedule)) (err u103))
        
        (try! (as-contract (contract-call? token transfer available tx-sender tx-sender none)))
        (ok (map-set vesting-schedules tx-sender (merge schedule {
            claimed-amount: (+ (get claimed-amount schedule) available)
        })))
    )
)

;; Read-only Helpers
(define-read-only (calculate-vested-amount (user principal))
    (let
        ((schedule (unwrap! (map-get? vesting-schedules user) u0)))
        (if (< stacks-block-height (get cliff-height schedule))
            u0
            (if (>= stacks-block-height (get end-height schedule))
                (- (get total-amount schedule) (get claimed-amount schedule))
                (let
                    ((total-vesting-time (- (get end-height schedule) (get start-height schedule)))
                     (elapsed-time (- stacks-block-height (get start-height schedule)))
                     (vested-total (/ (* (get total-amount schedule) elapsed-time) total-vesting-time)))
                    (- vested-total (get claimed-amount schedule))
                )
            )
        )
    )
)
