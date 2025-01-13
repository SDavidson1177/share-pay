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

    function establishParticipant(address _owner, string memory _title, address participant) private {
        vm.prank(participant);
        pay.requestToJoin(_owner, _title);

        vm.prank(_owner);
        pay.acceptRequest(_title, participant);
    }

    function payAndWarp(string memory _title, uint _warp_time) private {
        pay.acceptPayment(_title);
        vm.warp(block.timestamp + _warp_time);
    }

    function test_CreateBill() public {
        vm.prank(address(0));
        pay.createBill("test_bill", 100, 4 weeks);
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
        pay.createBill(bill_name, 100, 4 weeks);
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
        for (uint160 i = 0; i < participants.length; i++) {
            participants[i] = address(i+1234);
        }
        
        // Fund accounts
        vm.prank(owner);
        pay.createBill(_bill_name, 29, 4 weeks);
        vm.deal(owner, 1000);
        for (uint i = 0; i < 4; i++) {
            vm.deal(participants[i], 1000);
        }

        // Add participants
        establishParticipants(owner, _bill_name, participants);

        // Participants deposit
        for (uint i = 0; i < 4; i++) {
            vm.prank(participants[i]);
            pay.deposit{value: 20}();
            assertEq(participants[i].balance, 980);
        }
        assertEq(address(pay).balance, 80);

        // Owner Accepts payment
        assertEq(owner.balance, 1000);

        vm.prank(owner);
        payAndWarp(_bill_name, 3 weeks);
        assertEq(owner.balance, 1024);
        assertEq(address(pay).balance, 56);

        // Test a delta that is too short (3 weeks, not 4 weeks)
        vm.expectRevert();
        vm.prank(owner);
        payAndWarp(_bill_name, 4 weeks);

        // Add proper delta.
        // Since there is a remainder when splitting the bill, owner and participants
        // need to take turns paying the extra cost. That's why the owner receives 23 wei
        // instead of 24 wei. The owner covers the extra cost this time.
        vm.warp(block.timestamp + 4 weeks);
        vm.prank(owner);
        payAndWarp(_bill_name, 4 weeks);
        assertEq(owner.balance, 1047);
        assertEq(address(pay).balance, 33);
    }

    function test_Pause() public {
        address owner = address(0);
        address participant = address(1234);
        string memory bill_name = "test_bill";
        
        // Fund accounts
        vm.deal(owner, 100 ether);
        vm.deal(participant, 100 ether);

        // Create Bill
        vm.prank(owner);
        pay.createBill(bill_name, 10 ether, 4 weeks);

        establishParticipant(owner, bill_name, participant);

        // Deposit funds
        vm.prank(participant);
        pay.deposit{value: 50 ether}();

        // Make payments
        vm.prank(owner);
        payAndWarp(bill_name, 4 weeks);
        assertEq(owner.balance, 105 ether);

        // Pause
        vm.prank(participant);
        pay.pause(owner, bill_name);
        
        vm.prank(owner);
        vm.expectRevert();
        payAndWarp(bill_name, 4 weeks);

        // Unpause
        vm.prank(participant);
        pay.unpause(owner, bill_name);

        vm.prank(owner);
        payAndWarp(bill_name, 4 weeks);
        assertEq(owner.balance, 110 ether);
    }

    function test_Leave() public {
        address owner = address(0);
        address[] memory participants = new address[](2);
        string memory bill_name = "test_bill";
        for (uint160 i = 0; i < participants.length; i++) {
            participants[i] = address(i+1234);
        }
        
        // Fund accounts
        vm.deal(owner, 100 ether);
        for (uint160 i = 0; i < participants.length; i++) {
            vm.deal(participants[i], 100 ether);
        }
        
        // Create Bill
        vm.prank(owner);
        pay.createBill(bill_name, 30 ether, 4 weeks);

        establishParticipants(owner, bill_name, participants);

        // Deposit funds
        for (uint i = 0; i < participants.length; i++) {
            vm.prank(participants[i]);
            pay.deposit{value: 80 ether}();
        }

        // Make payments
        vm.prank(owner);
        payAndWarp(bill_name, 4 weeks);
        assertEq(owner.balance, 120 ether);

        // Leave
        vm.prank(participants[0]);
        pay.leave(owner, bill_name);
        
        vm.prank(owner);
        vm.expectRevert();
        payAndWarp(bill_name, 4 weeks);

        // Unpause remaining participant
        vm.prank(participants[1]);
        pay.unpause(owner, bill_name);

        vm.prank(owner);
        payAndWarp(bill_name, 4 weeks);
        assertEq(owner.balance, 135 ether);
    }

    function test_Withdrawls() public {
        address owner = address(0);
        address participant = address(2);
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
