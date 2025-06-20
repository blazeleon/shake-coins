/// Module: shake_coins
module shake_coins::shake_coins;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::sui::SUI;

public struct PrizePool has key {
    id: UID,
    amount: Balance<SUI>,
}

public struct AdminCap has key {
    id: UID,
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

