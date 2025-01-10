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
        vm.prank(address(0));
        pay.createBill("test_bill", 100);
        SharePay.Bill memory b = pay.getBill(address(0), "test_bill");
        assertEq(b.title, "test_bill");
        assertEq(b.amount, 100);

        // failure cases
        vm.expectRevert();
        pay.getBill(address(0), "null_bill");
    }

    function test_AddParticipant() public {
        string memory bill_name = "test_bill";
        address owner = address(0);
        address participant = address(1);

        // create bill
        vm.prank(owner);
        pay.createBill(bill_name, 100);
        SharePay.Bill memory b = pay.getBill(owner, bill_name);
        assertEq(b.requests.length, 0);

        // request participation
        vm.prank(participant);
        pay.requestToJoin(owner, bill_name);
        b = pay.getBill(owner, bill_name);
        assertEq(b.requests.length, 1);
        assertEq(b.participants.length, 0);

        // failure case (non-owner)
        vm.expectRevert();
        pay.acceptRequest(bill_name, participant);

        // accept participation
        vm.prank(owner);
        pay.acceptRequest(bill_name, address(1));
        b = pay.getBill(owner, bill_name);
        assertEq(b.participants.length, 1);
    }
}
