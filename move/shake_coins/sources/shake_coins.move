/// Module: shake_coins
module shake_coins::shake_coins;

use std::ascii::String;
use std::type_name;
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::sui::SUI;
use sui::random::Random;

const EBalanceIsInsufficient: u64 = 0;

public struct PrizePool has key {
    id: UID,
    amount: Balance<SUI>,
}

public struct AdminCap has key {
    id: UID,
}

/// Events
public struct PrizePoolCreated has copy, drop {
    id: ID,
    amount: u64,
}

public struct PrizeDeposit has copy, drop {
    from: address,
    coin_type: String,
    amount: u64,
}

public struct PrizeWithdraw has copy, drop {
    to: address,
    coin_type: String,
    amount: u64,
}

fun init(ctx: &mut TxContext) {
    // Initialize admin capabilities and bind it to the sender
    transfer::transfer(
        AdminCap {
            id: object::new(ctx),
        },
        ctx.sender(),
    );
    let pool_id = object::new(ctx);
    // Emit an event for the creation of the prize pool
    event::emit(PrizePoolCreated {
        id: object::uid_to_inner(&pool_id),
        amount: 0,
    });
    // Create the prize pool and share it
    transfer::share_object(PrizePool {
        id: pool_id,
        amount: balance::zero<SUI>(),
    });
}

/// Returns the total amount of SUI coins in the prize pool.
public fun get_prize_amount(prize_pool: &PrizePool): u64 {
    balance::value(&prize_pool.amount)
}

// === Entrypoints ===

public entry fun shake(
    prize_pool: &mut PrizePool,
    coins: &mut Coin<SUI>,
    content: u8,
    random: &Random,
    ctx: &mut TxContext,
) {
    // let total_prize = get_prize_amount(&prize_pool);

}

/// Deposit SUI coins into the prize pool.
public entry fun deposit_prize(prize_pool: &mut PrizePool, coins: Coin<SUI>, ctx: &mut TxContext) {
    let amt = coin::value(&coins);
    // Emit an event for the deposit
    event::emit(PrizeDeposit {
        from: ctx.sender(),
        coin_type: type_name::into_string(type_name::get<SUI>()),
        amount: amt,
    });
    coin::put<SUI>(&mut prize_pool.amount, coins);
}

/// Withdraw SUI coins from the prize pool.
/// Only the admin can withdraw coins from the prize pool.
public entry fun withdraw_prize(
    _: &AdminCap,
    prize_pool: &mut PrizePool,
    amount: u64,
    receiver: address,
    ctx: &mut TxContext,
) {
    let total_balance = balance::value<SUI>(&prize_pool.amount);
    // Ensure the prize pool has enough balance to withdraw the requested amount
    assert!(total_balance >= amount, EBalanceIsInsufficient);
    // Emit an event for the withdrawal
    event::emit(PrizeWithdraw {
        to: receiver,
        coin_type: type_name::into_string(type_name::get<SUI>()),
        amount,
    });
    let withdrawn_coin: Coin<SUI> = coin::take<SUI>(&mut prize_pool.amount, amount, ctx);
    transfer::public_transfer(withdrawn_coin, receiver);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
