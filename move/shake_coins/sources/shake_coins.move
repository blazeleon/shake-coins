/// Module: shake_coins
module shake_coins::shake_coins;

use std::ascii::String;
use std::type_name;
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::sui::SUI;

const EBalanceIsInsufficient: u64 = 0;

public struct PrizePool has key {
    id: UID,
    amount: Balance<SUI>,
}

public struct AdminCap has key {
    id: UID,
}

/// Events
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

    // Create the prize pool and share it
    transfer::share_object(PrizePool {
        id: object::new(ctx),
        amount: balance::zero<SUI>(),
    });
}

/// Deposit SUI coins into the prize pool.
public entry fun deposit_prize(
    prize_pool: &mut PrizePool,
    sui_object: &mut Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext,
) {
    let new_coin = coin::split(sui_object, amount, ctx);
    event::emit(PrizeDeposit {
        from: ctx.sender(),
        coin_type: type_name::into_string(type_name::get<SUI>()),
        amount,
    });
    coin::put<SUI>(&mut prize_pool.amount, new_coin);
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
    assert!(total_balance >= amount, EBalanceIsInsufficient);
    event::emit(PrizeWithdraw {
        to: receiver,
        coin_type: type_name::into_string(type_name::get<SUI>()),
        amount,
    });
    let withdrawn_coin: Coin<SUI> = coin::take<SUI>(&mut prize_pool.amount, amount, ctx);
    transfer::public_transfer(withdrawn_coin, receiver);
}
