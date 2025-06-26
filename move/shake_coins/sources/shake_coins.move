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
const EInvalidRandomRange: u64 = 1;
const EInvalidGuess: u64 = 2;
const EDivisorCannotBeZero: u64 = 3;

const RANDOM_HH: u8 = 0;
const RANDOM_HT_TH: u8 = 1;
const RANDOM_TT: u8 = 2;

const DEFAULT_REWARD_HH: u64 = 275;
const DEFAULT_REWARD_TT: u64 = 275;
const DEFAULT_REWARD_HT: u64 = 90;
const DEFAULT_DIVISOR: u64 = 100;
const DEFAULT_MIN_BET_AMOUNT: u64 = 10000000; // 0.01 SUI

public struct PrizePool has key {
    id: UID,
    amount: Balance<SUI>,
    min_bet_amount: u64,
    hh_multiplier: u64,
    hh_divisor: u64,
    tt_multiplier: u64,
    tt_divisor: u64,
    ht_th_multiplier: u64,
    ht_th_divisor: u64,
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

public struct ShakeRecord has copy, drop {
    bet_user: address,
    bet_amt: u64,
    bet_coin: String,
    bet_value: u8,
    shake_value: u8,
    random_raw: u8,
    is_winner: bool,
    reward_amt: u64,
    total_received_amt: u64,
}

public struct OddsUpdate has copy, drop {
    pool_id: ID,
    hh_multiplier: u64,
    hh_divisor: u64,
    tt_multiplier: u64,
    tt_divisor: u64,
    ht_th_multiplier: u64,
    ht_th_divisor: u64,
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
    event::emit(OddsUpdate {
        pool_id: object::uid_to_inner(&pool_id),
        hh_multiplier: DEFAULT_REWARD_HH,
        hh_divisor: DEFAULT_DIVISOR,
        tt_multiplier: DEFAULT_REWARD_TT,
        tt_divisor: DEFAULT_DIVISOR,
        ht_th_multiplier: DEFAULT_REWARD_HT,
        ht_th_divisor: DEFAULT_DIVISOR,
    });
    // Create the prize pool and share it
    transfer::share_object(PrizePool {
        id: pool_id,
        amount: balance::zero<SUI>(),
        min_bet_amount: DEFAULT_MIN_BET_AMOUNT,
        hh_multiplier: DEFAULT_REWARD_HH,
        hh_divisor: DEFAULT_DIVISOR,
        tt_multiplier: DEFAULT_REWARD_TT,
        tt_divisor: DEFAULT_DIVISOR,
        ht_th_multiplier: DEFAULT_REWARD_HT,
        ht_th_divisor: DEFAULT_DIVISOR,
    });
}

/// Deposits coins into the prize pool.
fun deposit(prize_pool: &mut PrizePool, coins: Coin<SUI>) {
    coin::put<SUI>(&mut prize_pool.amount, coins);
}

/// Withdraws a specified amount from the prize pool.
/// Returns the withdrawn coins.
fun withdraw(prize_pool: &mut PrizePool, amount: u64, ctx: &mut TxContext): Coin<SUI> {
    let total_balance = balance::value<SUI>(&prize_pool.amount);
    // Ensure the prize pool has enough balance to withdraw the requested amount
    assert!(total_balance >= amount, EBalanceIsInsufficient);
    coin::take<SUI>(&mut prize_pool.amount, amount, ctx)
}

/// Returns a random value in the range [min, max).
fun get_random_range(random: &Random, min: u64, max: u64, ctx: &mut TxContext): u8 {
    let mut random_generator = random::new_generator(random, ctx);
    let random_value: u64 = random::generate_u64_in_range(&mut random_generator, min, max);
    random_value as u8
}

/// Calculates the rewards based on the bet content and amount.
public fun calculate_rewards(bet_content: u8, bet_amt: u64): u64 {
    let payout: u64;
    if (bet_content == RANDOM_HH) {
        payout = bet_amt * 275 / 100;
    } else if (bet_content == RANDOM_TT) {
        payout = bet_amt * 275 / 100;
    } else {
        payout = bet_amt * 90 / 100;
    };
    payout
}

/// Returns the result of the guess.
fun get_guess_result(guess: u8, random: &Random, ctx: &mut TxContext): (bool, u8, u8) {
    let raw_value = get_random_range(random, 0, 3, ctx);
    assert!(raw_value < 4, EInvalidRandomRange);
    let actual_result: u8;
    if (raw_value == 0) {
        actual_result = RANDOM_HH;
    } else if (raw_value == 2) {
        actual_result = RANDOM_TT;
    } else {
        actual_result = RANDOM_HT_TH;
    };
    (guess == actual_result, actual_result, raw_value)
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
    bet_coins: Coin<SUI>,
    guess: u8,
    random: &Random,
    ctx: &mut TxContext,
) {
    assert!(guess < 3, EInvalidGuess);
    let (is_winner, actual_result, raw_value) = get_guess_result(guess, random, ctx);
    let bet_amt = coin::value(&bet_coins);
    let current_user = ctx.sender();
    if (is_winner) {
        let payout = calculate_rewards(actual_result, bet_amt);
        // Emit an event for the prize withdrawal
        event::emit(PrizeWithdraw {
            to: current_user,
            coin_type: type_name::into_string(type_name::get<SUI>()),
            amount: payout,
            flow_type: FundFlowType::RewardsOut,
        });
        let rewards = withdraw(prize_pool, payout, ctx);
        let mut new_coins = bet_coins;
        coin::join(&mut new_coins, rewards);
        // Emit an event for the shake result
        event::emit(ShakeRecord {
            bet_user: current_user,
            bet_amt,
            bet_coin: type_name::into_string(type_name::get<SUI>()),
            bet_value: guess,
            shake_value: actual_result,
            random_raw: raw_value,
            is_winner,
            reward_amt: payout,
            total_received_amt: coin::value(&new_coins),
        });
        transfer::public_transfer(new_coins, current_user);
    } else {
        // Emit an event for the shake result
        event::emit(ShakeRecord {
            bet_user: current_user,
            bet_amt,
            bet_coin: type_name::into_string(type_name::get<SUI>()),
            bet_value: guess,
            shake_value: actual_result,
            random_raw: raw_value,
            is_winner,
            reward_amt: 0,
            total_received_amt: 0,
        });
        // Emit an event for the deposit
        event::emit(PrizeDeposit {
            from: current_user,
            coin_type: type_name::into_string(type_name::get<SUI>()),
            amount: bet_amt,
            flow_type: FundFlowType::EarningsIn,
        });
        deposit(prize_pool, bet_coins);
    }
}

/// Deposit SUI coins into the prize pool.
public entry fun deposit_prize(prize_pool: &mut PrizePool, coins: Coin<SUI>, ctx: &mut TxContext) {
    let amt = coin::value(&coins);
    // Emit an event for the deposit
    event::emit(PrizeDeposit {
        from: ctx.sender(),
        coin_type: type_name::into_string(type_name::get<SUI>()),
        amount: amt,
        flow_type: FundFlowType::FoundationIn,
    });
    deposit(prize_pool, coins);
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

public entry fun update_odds(
    _: &AdminCap,
    prize_pool: &mut PrizePool,
    hh_multiplier: u64,
    hh_divisor: u64,
    tt_multiplier: u64,
    tt_divisor: u64,
    ht_th_multiplier: u64,
    ht_th_divisor: u64,
) {
    assert!(hh_divisor > 0 && tt_divisor > 0 && ht_th_divisor > 0, EDivisorCannotBeZero);
    prize_pool.hh_multiplier = hh_multiplier;
    prize_pool.hh_divisor = hh_divisor;
    prize_pool.tt_multiplier = tt_multiplier;
    prize_pool.tt_divisor = tt_divisor;
    prize_pool.ht_th_multiplier = ht_th_multiplier;
    prize_pool.ht_th_divisor = ht_th_divisor;
    event::emit(OddsUpdate {
        pool_id: object::uid_to_inner(&prize_pool.id),
        hh_multiplier,
        hh_divisor,
        tt_multiplier,
        tt_divisor,
        ht_th_multiplier,
        ht_th_divisor,
    });
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun get_random_for_testing(random: &Random, min: u64, max: u64, ctx: &mut TxContext): u8 {
    get_random_range(random, min, max, ctx)
}

#[test_only]
public fun shake_for_testing(
    prize_pool: &mut PrizePool,
    bet_coins: Coin<SUI>,
    guess: u8,
    random: &Random,
    ctx: &mut TxContext,
): (bool, u8) {
    assert!(guess < 3, EInvalidGuess);
    let (is_winner, actual_result, raw_value) = get_guess_result(guess, random, ctx);
    let bet_amt = coin::value(&bet_coins);
    let current_user = ctx.sender();
    if (is_winner) {
        let payout = calculate_rewards(actual_result, bet_amt);
        event::emit(PrizeWithdraw {
            to: current_user,
            coin_type: type_name::into_string(type_name::get<SUI>()),
            amount: payout,
            flow_type: FundFlowType::RewardsOut,
        });
        let rewards = withdraw(prize_pool, payout, ctx);
        let mut new_coins = bet_coins;
        coin::join(&mut new_coins, rewards);
        event::emit(ShakeRecord {
            bet_user: current_user,
            bet_amt,
            bet_coin: type_name::into_string(type_name::get<SUI>()),
            bet_value: guess,
            shake_value: actual_result,
            random_raw: raw_value,
            is_winner,
            reward_amt: payout,
            total_received_amt: coin::value(&new_coins),
        });
        transfer::public_transfer(new_coins, current_user);
    } else {
        event::emit(ShakeRecord {
            bet_user: current_user,
            bet_amt,
            bet_coin: type_name::into_string(type_name::get<SUI>()),
            bet_value: guess,
            shake_value: actual_result,
            random_raw: raw_value,
            is_winner,
            reward_amt: 0,
            total_received_amt: 0,
        });
        event::emit(PrizeDeposit {
            from: current_user,
            coin_type: type_name::into_string(type_name::get<SUI>()),
            amount: bet_amt,
            flow_type: FundFlowType::EarningsIn,
        });
        deposit(prize_pool, bet_coins);
    };
    (is_winner, actual_result)
}
