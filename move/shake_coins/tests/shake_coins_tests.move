#[test_only]
module shake_coins::shake_coins_tests;

use shake_coins::shake_coins::{Self, PrizePool, AdminCap};
use sui::coin::{mint_for_testing, Coin};
use sui::random::{Self, Random};
use sui::sui::SUI;
use sui::test_scenario;
use sui::test_utils::assert_eq;

#[test]
fun test_deposit_and_withdraw_prize() {
    let user = @0x1;
    // begin
    let mut scenario_val = test_scenario::begin(user);
    let scenario = &mut scenario_val;

    shake_coins::init_for_testing(test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, user);
    {
        // Testing the deposit_prize function
        let mut prize_pool = test_scenario::take_shared<PrizePool>(scenario);
        // Checking the initial prize amount
        assert_eq(shake_coins::get_prize_amount(&prize_pool), 0);

        let deposit_amt: u64 = 10000000;
        let sui_coins: Coin<SUI> = mint_for_testing<SUI>(deposit_amt, test_scenario::ctx(scenario));
        shake_coins::deposit_prize(
            &mut prize_pool,
            sui_coins,
            test_scenario::ctx(scenario),
        );
        // Checking the prize amount after deposit
        assert_eq(shake_coins::get_prize_amount(&prize_pool), deposit_amt);

        // Testing the withdraw_prize function
        let user2 = @0x2;
        let withdraw_amt: u64 = 1000000;
        let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
        shake_coins::withdraw_prize(
            &adminCap,
            &mut prize_pool,
            withdraw_amt,
            user2,
            test_scenario::ctx(scenario),
        );
        // Checking the prize amount after withdrawal
        assert_eq(shake_coins::get_prize_amount(&prize_pool), 9000000);

        // Returning objects ownership to test_scenario.
        test_scenario::return_to_sender(scenario, adminCap);
        test_scenario::return_shared(prize_pool);
    };
    // end
    test_scenario::end(scenario_val);
}

#[test]
fun test_random() {
    let current_user = @0x0;
    let mut scenario_val = test_scenario::begin(current_user);
    let scenario = &mut scenario_val;

    shake_coins::init_for_testing(scenario.ctx());

    random::create_for_testing(scenario.ctx());
    test_scenario::next_tx(scenario, current_user);
    let mut random_state: Random = test_scenario::take_shared<Random>(scenario);
    random_state.update_randomness_state_for_testing(
        0,
        x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
        scenario.ctx(),
    );

    let mut count = 200u64;
    let mut list = vector::empty<u8>();
    let expected_0 = 0u8;
    let expected_1 = 1u8;
    let expected_2 = 2u8;
    let expected_3 = 3u8;
    while (count > 0) {
        let random_value = shake_coins::get_random_for_testing(
            &random_state,
            0,
            3,
            scenario.ctx(),
        );
        // Ensure the random value is within the expected range [0, 3]
        assert!(random_value <= 3 && random_value >= 0, 0);
        vector::push_back(&mut list, random_value);
        count = count - 1;
    };
    // Check if the list contains all expected values [0-3]
    assert!(vector::contains<u8>(&list, &expected_0), 0);
    assert!(vector::contains<u8>(&list, &expected_1), 0);
    assert!(vector::contains<u8>(&list, &expected_2), 0);
    assert!(vector::contains<u8>(&list, &expected_3), 0);

    test_scenario::return_shared(random_state);
    test_scenario::end(scenario_val);
}
