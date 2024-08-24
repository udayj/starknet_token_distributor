// SPDX-License-Identifier: MIT

#[starknet::contract]
pub mod LockedToken {
    use core::array::{Array, ArrayTrait, Span};
    use core::box::BoxTrait;
    use core::poseidon::poseidon_hash_span;
    use core::integer::u256;
    use core::ecdsa::check_ecdsa_signature;
    use core::integer::BoundedInt;
    use starknet_token_distributor::interface::{
        IERC20, IERC20CamelOnly, ERC20ABIDispatcher, ERC20ABIDispatcherTrait, TDAdmin, TDUser,
    };

    use starknet::{ContractAddress, EthAddress};
    use starknet::{get_caller_address, get_block_timestamp, get_contract_address, get_tx_info};
    use core::traits::{Default, Into, TryInto};
    use core::num::traits::Zero;


    #[storage]
    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _total_supply: u256,
        _balances: LegacyMap<ContractAddress, u256>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        _owner: ContractAddress,
        _oracle_public_key: felt252,
        _claim_start: u64,
        _claim_duration: u64,
        _swap_start: u64,
        _swap_duration: u64,
        _proj_token_address: ContractAddress,
        _tokens_claimed: u256,
        _tokens_swapped: u256,
        _has_claimed: LegacyMap::<EthAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        TokenClaimed: TokenClaimed,
        TokenSwapped: TokenSwapped,
        ClaimStartTimeUpdated: ClaimStartTimeUpdated,
        ClaimDurationUpdated: ClaimDurationUpdated,
        SwapStartTimeUpdated: SwapStartTimeUpdated,
        SwapDurationUpdated: SwapDurationUpdated,
        ProjTokenAddressUpdated: ProjTokenAddressUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256
    }

    #[derive(Drop, starknet::Event)]
    struct TokenClaimed {
        #[key]
        l1_address: EthAddress,
        #[key]
        l2_address: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct TokenSwapped {
        #[key]
        l2_address: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ClaimStartTimeUpdated {
        previous_claim_start: u64,
        new_claim_start: u64
    }

    #[derive(Drop, starknet::Event)]
    struct ClaimDurationUpdated {
        previous_claim_duration: u64,
        new_claim_duration: u64
    }

    #[derive(Drop, starknet::Event)]
    struct SwapStartTimeUpdated {
        previous_swap_start: u64,
        new_swap_start: u64
    }

    #[derive(Drop, starknet::Event)]
    struct SwapDurationUpdated {
        previous_swap_duration: u64,
        new_swap_duration: u64
    }

    #[derive(Drop, starknet::Event)]
    struct ProjTokenAddressUpdated {
        previous_address: ContractAddress,
        new_address: ContractAddress
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, oracle_public_key: felt252) {
        self.initializer('Locked Proj Token', 'wPROJ');
        assert(!owner.is_zero(), 'TD: Owner is 0');
        self._owner.write(owner);
        assert(oracle_public_key != 0, 'TD: Oracle pubkey is 0');
        self._oracle_public_key.write(oracle_public_key);
    }

    //////////////
    // External //
    //////////////

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            18_u8
        }

        fn total_supply(self: @ContractState) -> u256 {
            self._total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self._balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self._allowances.read((owner, spender))
        }

        // This ERC20 represents a locked token and hence transfer, trasnfer_from and approve are not required
        // The function definitions are kept here to conform to ERC20 impl
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            assert(true == false, 'TD: Invalid call');
            false
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            assert(true == false, 'TD: Invalid call');
            false
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            assert(true == false, 'TD: Invalid call');
            false
        }
    }

    // Proxy functions for camel Case
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl of IERC20CamelOnly<ContractState> {
        fn totalSupply(self: @ContractState) -> u256 {
            ERC20Impl::total_supply(self)
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            ERC20Impl::balance_of(self, account)
        }

        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            assert(true == false, 'TD: Invalid call');
            false
        }
    }

    #[abi(embed_v0)]
    impl TDAdminImpl of TDAdmin<ContractState> {
        // @dev - Owner only function to set claim start time
        fn set_claim_start_time(ref self: ContractState, time: u64) {
            self._assert_owner();
            let current_time = get_block_timestamp();
            assert(time >= current_time, 'TD: Start time already passed');
            let prev_time = self._claim_start.read();
            self._claim_start.write(time);
            self
                .emit(
                    ClaimStartTimeUpdated { previous_claim_start: prev_time, new_claim_start: time }
                );
        }

        // @dev - Owner only function to set claim duration
        fn set_claim_duration(ref self: ContractState, time: u64) {
            self._assert_owner();
            let prev_time = self._claim_duration.read();
            self._claim_duration.write(time);
            self
                .emit(
                    ClaimDurationUpdated {
                        previous_claim_duration: prev_time, new_claim_duration: time
                    }
                );
        }

        // @dev - Owner only function to set swap start time
        fn set_swap_start_time(ref self: ContractState, time: u64) {
            self._assert_owner();
            let current_time = get_block_timestamp();
            assert(time >= current_time, 'TD: Start time already passed');
            let prev_time = self._swap_start.read();
            self._swap_start.write(time);
            self
                .emit(
                    SwapStartTimeUpdated { previous_swap_start: prev_time, new_swap_start: time }
                );
        }

        // @dev - Owner only function to set swap duration
        fn set_swap_duration(ref self: ContractState, time: u64) {
            self._assert_owner();
            let prev_time = self._swap_duration.read();
            self._swap_duration.write(time);
            self
                .emit(
                    SwapDurationUpdated {
                        previous_swap_duration: prev_time, new_swap_duration: time
                    }
                );
        }

        // @dev - Owner only function to update owner address
        fn update_owner_address(ref self: ContractState, new_owner: ContractAddress) {
            self._assert_owner();
            assert(!new_owner.is_zero(), 'TD: Owner is 0');
            self._owner.write(new_owner);
        }

        // @dev - Owner only function to update oracle public key
        // This public key is used to verify claim signatures
        fn update_oracle_public_key(ref self: ContractState, new_key: felt252) {
            self._assert_owner();
            assert(new_key != 0, 'TD: Public key is 0');
            self._oracle_public_key.write(new_key);
        }

        // @dev - Owner only function to enable owner to withdraw unclaimed tokens
        fn withdraw_unclaimed_tokens(ref self: ContractState, recipient: ContractAddress) {
            self._assert_owner();
            assert(!recipient.is_zero(), 'TD: Recipient is 0');

            // can withdraw only after claim duration is over
            let current_time = get_block_timestamp();
            assert(
                current_time >= self._claim_start.read() + self._claim_duration.read(),
                'TD: Claim period not over'
            );

            let token_address = self._proj_token_address.read();

            let self_proj_balance = ERC20ABIDispatcher {
                contract_address: token_address
            }.balance_of(get_contract_address());

            // Tokens claimed must be strictly less than the total amount of airdrop tokens transffered to
            // the token distributor contract
            assert(self_proj_balance > self._tokens_claimed.read(), 'TD: All tokens claimed');
            let unclaimed_tokens = self_proj_balance - self._tokens_claimed.read();

            // Transfer only the unclaimed tokens
            ERC20ABIDispatcher {
                contract_address: token_address
            }.transfer(recipient, unclaimed_tokens);
        }

        // @dev - Onwer only function to transfer the unswapped Proj tokens
        fn withdraw_unswapped_tokens(ref self: ContractState, recipient: ContractAddress) {
            self._assert_owner();
            assert(!recipient.is_zero(), 'TD: Recipient is 0');

            // can withdraw only after swap tiem is over
            let current_time = get_block_timestamp();
            assert(
                current_time >= self._swap_start.read() + self._swap_duration.read(),
                'TD: Swap period not over'
            );

            // Tokens swapped must be less than tokens claimed
            assert(
                self._tokens_claimed.read() > self._tokens_swapped.read(), 'TD: All tokens swapped'
            );
            let unswapped_tokens = self._tokens_claimed.read() - self._tokens_swapped.read();

            self._total_supply.write(self._total_supply.read() - unswapped_tokens);

            // The following assertion should never be false since total supply increases during claim
            // and decreases during swapping of tokens by users
            assert(
                self._total_supply.read() == u256 { low: 0, high: 0 },
                'TD: Unaccounted tokens remain'
            );

            let token_address = self._proj_token_address.read();

            // Transfer unswapped tokens
            ERC20ABIDispatcher {
                contract_address: token_address
            }.transfer(recipient, unswapped_tokens);
        }

        // @dev - Owner only function to set Proj token address
        fn set_proj_token_address(ref self: ContractState, token_address: ContractAddress) {
            self._assert_owner();
            assert(!token_address.is_zero(), 'TD: Proj token addr 0');
            let prev_address = self._proj_token_address.read();
            self._proj_token_address.write(token_address);
            self
                .emit(
                    ProjTokenAddressUpdated {
                        previous_address: prev_address, new_address: token_address
                    }
                );
        }

        // The following get functions are convenience functions to check the state of the system

        fn get_owner(self: @ContractState) -> ContractAddress {
            self._owner.read()
        }

        fn get_oracle_public_key(self: @ContractState) -> felt252 {
            self._oracle_public_key.read()
        }

        fn get_claim_start_time(self: @ContractState) -> u64 {
            self._claim_start.read()
        }

        fn get_claim_duration(self: @ContractState) -> u64 {
            self._claim_duration.read()
        }

        fn get_swap_start_time(self: @ContractState) -> u64 {
            self._swap_start.read()
        }

        fn get_swap_duration(self: @ContractState) -> u64 {
            self._swap_duration.read()
        }

        fn get_proj_token_address(self: @ContractState) -> ContractAddress {
            self._proj_token_address.read()
        }

        fn get_total_tokens_claimed(self: @ContractState) -> u256 {
            self._tokens_claimed.read()
        }

        fn get_total_tokens_swapped(self: @ContractState) -> u256 {
            self._tokens_swapped.read()
        }
    }

    #[abi(embed_v0)]
    impl TDUserImpl of TDUser<ContractState> {
        // @dev - Claim function to be called by the user
        // @param l1_address: User Eth address which is eligible for the airdrop claim
        // @param l2_address: User provided l2_address where user wants the locked tokens
        // @param amount: Airdrop claim amount
        // @param sig_r and sig_s - Signature as provided by claim verifying oracle
        fn claim(
            ref self: ContractState,
            l1_address: EthAddress,
            l2_address: ContractAddress,
            amount: u256,
            sig_r: felt252,
            sig_s: felt252
        ) {
            // Check that user has not already claimed the airdrop tokens
            assert(!self._has_claimed.read(l1_address), 'TD: Tokens already claimed');
            let current_time = get_block_timestamp();

            // Check claim is being made during claim duration
            assert(current_time >= self._claim_start.read(), 'TD: Claim period not started');
            assert(
                current_time < self._claim_start.read() + self._claim_duration.read(),
                'TD: Claim period over'
            );

            // Form message hash
            let message_hash = self._hash_args(l1_address, l2_address, amount);

            // Check signature
            let verification_result = check_ecdsa_signature(
                message_hash, self._oracle_public_key.read(), sig_r, sig_s
            );

            assert(verification_result, 'TD: Invalid signature');

            // Update claim status
            self._has_claimed.write(l1_address, true);
            self._tokens_claimed.write(self._tokens_claimed.read() + amount);

            let token_address = self._proj_token_address.read();

            let self_proj_balance = ERC20ABIDispatcher {
                contract_address: token_address
            }.balance_of(get_contract_address());

            // Verify that we have enough Proj tokens to cover this claim
            assert(self_proj_balance > self._tokens_claimed.read(), 'TD: All tokens claimed');

            // Mint locked tokens to user
            self._mint(l2_address, amount);

            self
                .emit(
                    TokenClaimed { l1_address: l1_address, l2_address: l2_address, amount: amount }
                );
        }

        // @dev - Swap function to be called by holders of locked Proj tokens to convert to Proj tokens
        fn swap(ref self: ContractState) {
            let current_time = get_block_timestamp();

            // Check swap is being done during swap time
            assert(current_time >= self._swap_start.read(), 'TD: Swap period not started');
            assert(
                current_time < self._swap_start.read() + self._swap_duration.read(),
                'TD: Swap period over'
            );

            let caller = get_caller_address();
            let balance = self._balances.read(caller);
            assert(balance != u256 { low: 0, high: 0 }, 'TD: No token to swap');

            // burn locked tokens
            self._burn(caller, balance);
            let token_address = self._proj_token_address.read();

            // Transfer equivalent amount of Proj tokens to user
            ERC20ABIDispatcher { contract_address: token_address }.transfer(caller, balance);

            // Update swapped tokens count
            self._tokens_swapped.write(self._tokens_swapped.read() + balance);
            self.emit(TokenSwapped { l2_address: caller, amount: balance });
        }

        // @dev - Function to check claim status of an L1 address
        fn has_claimed(self: @ContractState, l1_address: EthAddress) -> bool {
            self._has_claimed.read(l1_address)
        }
    }

    //////////////
    // Internal //
    //////////////

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252) {
            self._name.write(name_);
            self._symbol.write(symbol_);
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            self._total_supply.write(self._total_supply.read() + amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: Zero::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self._total_supply.write(self._total_supply.read() - amount);
            self._balances.write(account, self._balances.read(account) - amount);
            self.emit(Transfer { from: account, to: Zero::zero(), value: amount });
        }

        fn _assert_owner(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self._owner.read(), 'TD: Unauthorised Call');
        }

        // @dev - Function to form hash of message
        // hash = pedersen_hash(0, l1_address, l2_address, amount, chain_id, 5) - amount is 2 felts
        // we use this hash since compute_hash_on_elements(data) is calculated as
        // h(h(h(h(0, data[0]), data[1]), ...), data[n-1]), n)
        fn _hash_args(
            self: @ContractState, l1_address: EthAddress, l2_address: ContractAddress, amount: u256
        ) -> felt252 {
            let chain_id: felt252 = get_tx_info().unbox().chain_id;
            let args = array![chain_id, l1_address.into(), l2_address.into(), amount.low.into(), amount.high.into()].span();
            poseidon_hash_span(args)
        }
    }
}