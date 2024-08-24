// SPDX-License-Identifier: MIT
// Inspired by Open Zeppelin cairo contracts

use starknet::{ContractAddress, EthAddress};
use core::hash::LegacyHash;

#[starknet::interface]
pub trait IERC20<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
pub trait IERC20Camel<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
pub trait IERC20CamelOnly<TState> {
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::interface]
pub trait ERC20ABI<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
pub trait ERC20CamelABI<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
pub trait TDAdmin<TState> {
    fn set_claim_start_time(ref self: TState, time: u64);
    fn set_claim_duration(ref self: TState, time: u64);
    fn set_swap_start_time(ref self: TState, time: u64);
    fn set_swap_duration(ref self: TState, time: u64);
    fn update_owner_address(ref self: TState, new_owner: ContractAddress);
    fn update_oracle_public_key(ref self: TState, new_key: felt252);
    fn withdraw_unclaimed_tokens(ref self: TState, recipient: ContractAddress);
    fn withdraw_unswapped_tokens(ref self: TState, recipient: ContractAddress);
    fn set_proj_token_address(ref self: TState, token_address: ContractAddress);
    fn get_owner(self: @TState) -> ContractAddress;
    fn get_oracle_public_key(self: @TState) -> felt252;
    fn get_claim_start_time(self: @TState) -> u64;
    fn get_claim_duration(self: @TState) -> u64;
    fn get_swap_start_time(self: @TState) -> u64;
    fn get_swap_duration(self: @TState) -> u64;
    fn get_proj_token_address(self: @TState) -> ContractAddress;
    fn get_total_tokens_claimed(self: @TState) -> u256;
    fn get_total_tokens_swapped(self: @TState) -> u256;
}

#[starknet::interface]
pub trait TDUser<TState> {
    fn claim(
        ref self: TState,
        l1_address: EthAddress,
        l2_address: ContractAddress,
        amount: u256,
        sig_r: felt252,
        sig_s: felt252
    );

    fn swap(ref self: TState);
    fn has_claimed(self: @TState, l1_address: EthAddress) -> bool;
}
