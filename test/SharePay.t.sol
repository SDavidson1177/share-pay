// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SharePay} from "../src/SharePay.sol";

contract SharePayTest is Test {
    SharePay public pay;

    function setUp() public {
        pay = new SharePay();
    }

    function test_CreateBill() public {
        pay.createBill("test_bill", 100);
        SharePay.Bill memory b = pay.getBill("test_bill");
        assertEq(b.title, "test_bill");
        assertEq(b.amount, 100);
    }
}
