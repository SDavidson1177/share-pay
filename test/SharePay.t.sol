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
        (SharePay.Bill memory b, ) = pay.getBill("test_bill");
        assertEq(b.title, "test_bill");
        assertEq(b.amount, 100);

        // failure cases
        (SharePay.Bill memory c, ) = pay.getBill("null_bill");
        assert(pay.isBillNull(c));
        assert(!pay.isBillNull(b));
    }

    function test_AddParticipant() public {
        string memory bill_name = "test_bill";

        // create bill
        vm.prank(address(0));
        pay.createBill(bill_name, 100);
        (SharePay.Bill memory b, ) = pay.getBill(bill_name);
        assertEq(b.requests.length, 0);

        // request participation
        vm.prank(address(1));
        pay.requestToJoin(bill_name);
        (b, ) = pay.getBill(bill_name);
        assertEq(b.requests.length, 1);
        assertEq(b.participants.length, 0);

        // failure case (non-owner)
        vm.expectRevert();
        pay.acceptRequest(bill_name, address(1));

        // accept participation
        vm.prank(address(0));
        pay.acceptRequest(bill_name, address(1));
        (b, ) = pay.getBill(bill_name);
        assertEq(b.participants.length, 1);
    }
}
