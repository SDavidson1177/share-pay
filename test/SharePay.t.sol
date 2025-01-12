// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SharePay} from "../src/SharePay.sol";

contract SharePayTest is Test {
    SharePay public pay;

    function setUp() public {
        pay = new SharePay();
    }

    function establishParticipants(address _owner, string memory _title, address[] memory participants) private {
        for (uint i = 0; i < participants.length; i++) {
            vm.prank(participants[i]);
            pay.requestToJoin(_owner, _title);

            vm.prank(_owner);
            pay.acceptRequest(_title, participants[i]);
        }
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

    function test_Payments() public {
        address owner = address(0);
        string memory _bill_name = "test_bill";
        address[] memory participants = new address[](4);
        for (uint160 i = 0; i < 4; i++) {
            participants[i] = address(i+1);
        }
        
        // Fund accounts
        vm.prank(owner);
        pay.createBill(_bill_name, 100 ether);
        vm.deal(owner, 1000 ether);
        for (uint i = 0; i < 4; i++) {
            vm.deal(participants[i], 1000 ether);
        }

        // Add participants
        establishParticipants(owner, _bill_name, participants);

        // Participants deposit
        for (uint i = 0; i < 4; i++) {
            vm.prank(participants[i]);
            pay.deposit{value: 20 ether}();
        }
        assertEq(address(pay).balance, 80 ether);

        // Owner Accepts payment
        vm.prank(owner);
        pay.acceptPayment(_bill_name);
        for (uint i = 0; i < 4; i++) {
            assertEq(participants[i].balance, 980 ether);
        }

        assertEq(owner.balance, 1080 ether);
        assertEq(address(pay).balance, 0 ether);
    }

    function test_Withdrawls() public {
        address owner = address(0);
        address participant = address(1234);
        vm.deal(owner, 1000 ether);
        vm.deal(participant, 1000 ether);

        vm.prank(owner);
        pay.deposit{value: 50 ether}();
        assertEq(owner.balance, 950 ether);
        assertEq(address(pay).balance, 50 ether);

        vm.prank(participant);
        pay.deposit{value: 100 ether}();
        assertEq(participant.balance, 900 ether);
        assertEq(address(pay).balance, 150 ether);

        vm.prank(owner);
        vm.expectRevert();
        pay.withdraw(80 ether);
        assertEq(address(pay).balance, 150 ether);

        vm.prank(owner);
        vm.expectRevert();
        pay.withdraw(120 ether);
        assertEq(address(pay).balance, 150 ether);

        vm.prank(owner);
        pay.withdraw(50 ether);
        assertEq(owner.balance, 1000 ether);
        assertEq(address(pay).balance, 100 ether);

        vm.prank(participant);
        pay.withdraw(100 ether);
        assertEq(participant.balance, 1000 ether);
    }
}
