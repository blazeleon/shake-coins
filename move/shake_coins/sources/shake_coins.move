/// Module: shake_coins
module shake_coins::shake_coins;

use std::ascii::String;
use std::type_name;
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::random::{Self, Random};
use sui::sui::SUI;

const EBalanceIsInsufficient: u64 = 0;

const RANDOM_HH: u8 = 0;
const RANDOM_HT_TH: u8 = 1;
const RANDOM_TT: u8 = 2;

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
    flow_type: FundFlowType,
}

public struct PrizeWithdraw has copy, drop {
    to: address,
    coin_type: String,
    amount: u64,
    flow_type: FundFlowType,
}

public struct ShakeResult has copy, drop {
    user: address,
    coin_amt: u64,
    coin_type: String,
    user_guess: u8,
    shake_result: u8,
    is_winner: bool,
    total_rewards: u64,
}

public enum FundFlowType has copy, drop {
    RewardsOut,
    EarningsIn,
    FoundationIn,
    FoundationOut,
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

fun deposit(prize_pool: &mut PrizePool, coins: Coin<SUI>, flow_type: FundFlowType, from: address) {
    let amt = coin::value(&coins);
    // Emit an event for the deposit
    event::emit(PrizeDeposit {
        from,
        coin_type: type_name::into_string(type_name::get<SUI>()),
        amount: amt,
        flow_type,
    });
    coin::put<SUI>(&mut prize_pool.amount, coins);
}

fun withdraw(prize_pool: &mut PrizePool, amount: u64, ctx: &mut TxContext): Coin<SUI> {
    let total_balance = balance::value<SUI>(&prize_pool.amount);
    // Ensure the prize pool has enough balance to withdraw the requested amount
    assert!(total_balance >= amount, EBalanceIsInsufficient);
    coin::take<SUI>(&mut prize_pool.amount, amount, ctx)
}

/// Returns the total amount of SUI coins in the prize pool.
public fun get_prize_amount(prize_pool: &PrizePool): u64 {
    balance::value(&prize_pool.amount)
}

// === Entrypoints ===

/// Shake the coins and determine the result based on a random value.
/// The user can guess the outcome of the shake, and if they guess correctly, they win a prize.
/// The possible outcomes are:
/// - 0: Heads and Heads (HH)
/// - 1: Heads and Tails or Tails and Heads (HT or TH)
/// - 2: Tails and Tails (TT)
/// The user can guess 0, 1, or 2.
/// For example: If the user guesses correctly, they win a prize based on the outcome:
/// - If the outcome is HH or TT, they win 2.75x their bet amount.
/// - If the outcome is HT or TH, they win 0.9x their bet amount.
/// If the user guesses incorrectly, their bet amount is deposited into the prize pool.
entry fun shake(
    prize_pool: &mut PrizePool,
    coins: Coin<SUI>,
    guess: u8,
    random: &Random,
    ctx: &mut TxContext,
) {
    let bet_amt = coin::value(&coins);
    assert!(guess <= 2, 0);
    // Using the random generator to determine the shake result
    let mut random_generator = random::new_generator(random, ctx);
    let random_value: u64 = random::generate_u64_in_range(&mut random_generator, 0, 3);
    assert!(random_value < 4, 0);
    let actual_result: u8;
    // Mapping the random value to the shake result
    if (random_value == 0) {
        actual_result = RANDOM_HH;
    } else if (random_value == 3) {
        actual_result = RANDOM_TT;
    } else {
        // random_value is 1 or 2
        actual_result = RANDOM_HT_TH;
    };
    let current_user = ctx.sender();
    // Judge the result of the shake
    if (guess == actual_result) {
        // Winner!
        let out_amt: u64;
        if (actual_result == 0) {
            out_amt = bet_amt * 275 / 100;
        } else if (actual_result == 2) {
            out_amt = bet_amt * 275 / 100;
        } else {
            out_amt = bet_amt * 90 / 100;
        };
        let rewards = withdraw(prize_pool, out_amt, ctx);
        let mut new_coins = coins;
        coin::join(&mut new_coins, rewards);
        // Emit an event for the prize withdrawal
        event::emit(PrizeWithdraw {
            to: current_user,
            coin_type: type_name::into_string(type_name::get<SUI>()),
            amount: out_amt,
            flow_type: FundFlowType::RewardsOut,
        });
        // Emit an event for the shake result
        event::emit(ShakeResult {
            user: current_user,
            coin_amt: bet_amt,
            coin_type: type_name::into_string(type_name::get<SUI>()),
            user_guess: guess,
            shake_result: actual_result,
            is_winner: true,
            total_rewards: coin::value(&new_coins),
        });
        transfer::public_transfer(new_coins, current_user);
    } else {
        // Loser!
        // Emit an event for the shake result
        event::emit(ShakeResult {
            user: current_user,
            coin_amt: bet_amt,
            coin_type: type_name::into_string(type_name::get<SUI>()),
            user_guess: guess,
            shake_result: actual_result,
            is_winner: false,
            total_rewards: 0,
        });
        deposit(prize_pool, coins, FundFlowType::EarningsIn, current_user);
    }
}

/// Deposit SUI coins into the prize pool.
public entry fun deposit_prize(prize_pool: &mut PrizePool, coins: Coin<SUI>, ctx: &mut TxContext) {
    deposit(prize_pool, coins, FundFlowType::FoundationIn, ctx.sender());
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
    let withdrawn_coin = withdraw(prize_pool, amount, ctx);
    // Emit an event for the withdrawal
    event::emit(PrizeWithdraw {
        to: receiver,
        coin_type: type_name::into_string(type_name::get<SUI>()),
        amount,
        flow_type: FundFlowType::FoundationOut,
    });
    transfer::public_transfer(withdrawn_coin, receiver);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
