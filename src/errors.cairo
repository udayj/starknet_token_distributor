pub mod Errors {
    pub const OWNER_ZERO:felt252 = 'TD: Owner is 0';
    pub const ORACLE_PUBKEY_ZERO:felt252 = 'TD: Oracle pubkey is 0';
    pub const START_TIME_PASSED: felt252 = 'TD: Start time already passed';
    pub const INVALID_CALL:felt252 = 'TD: Invalid call';
    pub const PUBKEY_ZERO:felt252 = 'TD: Public key is 0';
    pub const RECIPIENT_ZERO:felt252 = 'TD: Recipient is 0';
    pub const CLAIM_PERIOD_NOT_OVER:felt252 = 'TD: Claim period not over';
}