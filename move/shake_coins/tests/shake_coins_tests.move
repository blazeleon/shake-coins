#[test_only]
module shake_coins::shake_coins_tests;

use shake_coins::shake_coins::{Self, PrizePool, AdminCap};
use sui::coin::{mint_for_testing, Coin};
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
